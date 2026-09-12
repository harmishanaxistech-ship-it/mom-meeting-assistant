const express = require('express');
const router = express.Router();
const MOM = require('../models/MOM');
const { getTranslationProvider } = require('../services/providerFactory');
const {
  createMeeting,
  getMeetings,
  getMeetingById,
  updateMeeting,
  deleteMeeting,
  regenerateMOM,
} = require('../controllers/meetingController');
const {
  upload,
  uploadAudio,
  processMeeting,
  getProcessingStatus,
} = require('../controllers/processingController');
const {
  generateDocument,
  getDocuments,
} = require('../controllers/documentController');
const { protect } = require('../middleware/auth');

router.use(protect);

router.route('/').post(createMeeting).get(getMeetings);

router.get('/settings/team-members', async (req, res, next) => {
  try {
    const TeamMember = require('../models/TeamMember');
    const members = await TeamMember.find().sort({ name: 1 });
    res.status(200).json({ success: true, data: members.map(m => m.name) });
  } catch (error) {
    next(error);
  }
});

router.route('/:id').get(getMeetingById).put(updateMeeting).delete(deleteMeeting);

// Recording & Processing Endpoints (Section 28)
router.post('/:id/upload', upload.single('audio'), uploadAudio);
router.post('/:id/process', processMeeting);
router.post('/:id/regenerate-mom', regenerateMOM);
router.get('/:id/processing-status', getProcessingStatus);

// Multilingual Translation Endpoint with Caching
router.post('/:id/translate', async (req, res, next) => {
  try {
    const { targetLanguage, forceRegenerate = false } = req.body;
    const mom = await MOM.findOne({ meetingId: req.params.id });
    if (!mom) {
      return res.status(404).json({ success: false, error: 'MOM not found' });
    }

    const lang = targetLanguage || 'en';

    // 1. Check if translation is already cached (unless forceRegenerate is true)
    if (!forceRegenerate && mom.translations && mom.translations.get(lang)) {
      console.log(`[Translation Cache] Returning cached translation for language: ${lang}`);
      const cached = mom.translations.get(lang);
      return res.status(200).json({
        success: true,
        data: { mom: cached },
        fromCache: true,
      });
    }

    // 2. Otherwise generate via OpenAI
    const translationProvider = getTranslationProvider();
    const translatedMOM = await translationProvider.translateMOM(
      mom.toObject(),
      lang
    );

    // Save to translation cache map
    if (!mom.translations) {
      mom.translations = new Map();
    }
    mom.translations.set(lang, translatedMOM);
    await mom.save();

    res.status(200).json({
      success: true,
      data: { mom: translatedMOM },
      fromCache: false,
    });
  } catch (error) {
    console.error('[Translation Route Error]:', error.message);
    next(error);
  }
});

// Update MOM content (Save user edits)
router.put('/:id/mom', async (req, res, next) => {
  try {
    const {
      meetingSummary,
      agenda,
      keyDiscussionPoints,
      decisions,
      actionItems,
      pendingItems,
      risks,
      nextSteps,
      otherNotes,
      conclusion,
      language = 'en',
    } = req.body;

    let mom = await MOM.findOne({ meetingId: req.params.id });
    if (!mom) {
      return res.status(404).json({ success: false, error: 'MOM not found' });
    }

    if (meetingSummary !== undefined) mom.meetingSummary = meetingSummary;
    if (agenda !== undefined) mom.agenda = agenda;
    if (keyDiscussionPoints !== undefined) mom.keyDiscussionPoints = keyDiscussionPoints;
    if (decisions !== undefined) mom.decisions = decisions;
    if (actionItems !== undefined) mom.actionItems = actionItems;
    if (pendingItems !== undefined) mom.pendingItems = pendingItems;
    if (risks !== undefined) mom.risks = risks;
    if (nextSteps !== undefined) mom.nextSteps = nextSteps;
    if (otherNotes !== undefined) mom.otherNotes = otherNotes;
    if (conclusion !== undefined) mom.conclusion = conclusion;
    mom.isEditedByUser = true;

    // Clear translation cache when user edits so translation updates
    mom.translations = new Map();
    await mom.save();

    // Sync updated MOM to Master Excel Tracker
    try {
      const documentService = require('../services/document/DocumentService');
      const meeting = await require('../models/Meeting').findById(req.params.id);
      if (meeting) {
        await documentService.syncToMasterTracker(meeting, mom);
      }
    } catch (excelErr) {
      console.error('[MOM Update] Master Excel sync error:', excelErr.message);
    }

    res.status(200).json({
      success: true,
      message: 'MOM updated and saved successfully',
      data: { mom },
    });
  } catch (error) {
    next(error);
  }
});

// Master Excel Workbook Tracker Download Endpoint
router.get('/export/master-excel', async (req, res, next) => {
  try {
    const fs = require('fs');
    const path = require('path');
    const env = require('../config/env');
    const masterPath = path.join(env.upload.dir, 'MOM_Master_Tracker.xlsx');
    const promptsMasterPath = path.resolve(__dirname, '../../../prompts/MOM_Master_Tracker.xlsx');

    const filePath = fs.existsSync(masterPath) ? masterPath : promptsMasterPath;
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, error: 'Master Excel Tracker not found' });
    }

    res.download(filePath, 'MOM_Master_Tracker.xlsx');
  } catch (error) {
    next(error);
  }
});

// Document Generation & Retrieval Endpoints (Section 28)
router.route('/:id/document').post(generateDocument).get(getDocuments);

// 1-2 min Spoken Audio Summary Generation (English, Hindi, Gujarati)
const audioSummaryService = require('../services/ai/AudioSummaryService');
router.post('/:id/audio-summary', async (req, res, next) => {
  try {
    const { language = 'en', forceRegenerate = false, voice } = req.body;
    const meetingId = req.params.id;

    const mom = await MOM.findOne({ meetingId });
    if (!mom) {
      return res.status(404).json({ success: false, error: 'MOM not found for this meeting' });
    }

    const meeting = await require('../models/Meeting').findById(meetingId);

    // 1. Check if audio summary is already cached (unless forceRegenerate is true)
    if (!forceRegenerate && mom.audioSummaries && mom.audioSummaries.get(language)) {
      const cached = mom.audioSummaries.get(language);
      return res.status(200).json({
        success: true,
        data: cached,
        fromCache: true,
      });
    }

    // 2. Generate spoken script
    const momPayload = {
      ...mom.toObject(),
      title: meeting?.title || 'Meeting',
      meetingType: meeting?.meetingType || 'General Meeting',
      location: meeting?.location || '',
      participants: meeting?.participants || [],
      agenda: meeting?.agenda || mom.agenda || '',
    };

    const TeamKnowledge = require('../models/TeamKnowledge');
    const knowledgeDoc = await TeamKnowledge.findOne({ userId: req.user._id });
    const teamKnowledge = knowledgeDoc ? knowledgeDoc.learnedContext : '';

    const script = await audioSummaryService.generateScript(momPayload, meeting, teamKnowledge, language);

    // 3. Synthesize speech to MP3
    const audioResult = await audioSummaryService.textToSpeech(script, language, meetingId);

    const summaryRecord = {
      audioUrl: audioResult.audioUrl,
      script,
      language,
      durationSeconds: audioResult.durationSeconds,
      voice: audioResult.voice,
    };

    if (!mom.audioSummaries) {
      mom.audioSummaries = new Map();
    }
    mom.audioSummaries.set(language, summaryRecord);
    await mom.save();

    res.status(200).json({
      success: true,
      data: summaryRecord,
      fromCache: false,
    });
  } catch (error) {
    console.error('[AudioSummary Route Error]:', error.message);
    next(error);
  }
});

module.exports = router;
