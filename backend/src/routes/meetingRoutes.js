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
router.route('/:id').get(getMeetingById).put(updateMeeting).delete(deleteMeeting);

// Recording & Processing Endpoints (Section 28)
router.post('/:id/upload', upload.single('audio'), uploadAudio);
router.post('/:id/process', processMeeting);
router.get('/:id/processing-status', getProcessingStatus);

// Multilingual Translation Endpoint with Caching
router.post('/:id/translate', async (req, res, next) => {
  try {
    const { targetLanguage } = req.body;
    const mom = await MOM.findOne({ meetingId: req.params.id });
    if (!mom) {
      return res.status(404).json({ success: false, error: 'MOM not found' });
    }

    const lang = targetLanguage || 'en';

    // 1. Check if translation is already cached
    if (mom.translations && mom.translations.get(lang)) {
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
    if (conclusion !== undefined) mom.conclusion = conclusion;
    mom.isEditedByUser = true;

    // Clear translation cache when user edits so translation updates
    mom.translations = new Map();
    await mom.save();

    res.status(200).json({
      success: true,
      message: 'MOM updated and saved successfully',
      data: { mom },
    });
  } catch (error) {
    next(error);
  }
});

// Document Generation & Retrieval Endpoints (Section 28)
router.route('/:id/document').post(generateDocument).get(getDocuments);

module.exports = router;
