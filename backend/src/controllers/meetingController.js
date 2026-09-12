const fs = require('fs');
const Meeting = require('../models/Meeting');
const Transcript = require('../models/Transcript');
const MOM = require('../models/MOM');
const Document = require('../models/Document');
const ProcessingJob = require('../models/ProcessingJob');

/**
 * @desc    Create a new meeting
 * @route   POST /api/meetings
 * @access  Private
 */
const createMeeting = async (req, res, next) => {
  try {
    const { title, meetingType, dateTime, location, participants, agenda } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        success: false,
        error: 'Meeting title is required',
      });
    }

    const toTitleCase = (str) =>
      str.replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase());

    const meeting = await Meeting.create({
      userId: req.user._id,
      title: title.trim().charAt(0).toUpperCase() + title.trim().slice(1),
      meetingType: meetingType || 'General Meeting',
      dateTime: dateTime ? new Date(dateTime) : new Date(),
      location: location ? location.trim() : '',
      participants: Array.isArray(participants)
        ? participants.map((p) => toTitleCase(p.trim())).filter(Boolean)
        : [],
      agenda: agenda ? agenda.trim() : '',
      status: 'created',
    });

    res.status(201).json({
      success: true,
      data: { meeting },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all meetings for the logged-in user
 * @route   GET /api/meetings
 * @access  Private
 */
const getMeetings = async (req, res, next) => {
  try {
    const { status, meetingType } = req.query;
    const query = { userId: req.user._id };

    if (status) query.status = status;
    if (meetingType) query.meetingType = meetingType;

    const meetings = await Meeting.find(query).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: meetings.length,
      data: { meetings },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get single meeting by ID
 * @route   GET /api/meetings/:id
 * @access  Private
 */
const getMeetingById = async (req, res, next) => {
  try {
    const meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    // Include related records if they exist
    const transcript = await Transcript.findOne({ meetingId: meeting._id });
    const mom = await MOM.findOne({ meetingId: meeting._id });
    const documents = await Document.find({ meetingId: meeting._id });
    const processingJob = await ProcessingJob.findOne({ meetingId: meeting._id });

    res.status(200).json({
      success: true,
      data: {
        meeting,
        transcript,
        mom,
        documents,
        processingJob,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update meeting details
 * @route   PUT /api/meetings/:id
 * @access  Private
 */
const updateMeeting = async (req, res, next) => {
  try {
    const { title, meetingType, dateTime, location, participants, agenda, status, duration } =
      req.body;

    let meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    if (title !== undefined) meeting.title = title.trim().charAt(0).toUpperCase() + title.trim().slice(1);
    if (meetingType !== undefined) meeting.meetingType = meetingType;
    if (dateTime !== undefined) meeting.dateTime = new Date(dateTime);
    if (location !== undefined) meeting.location = location.trim();
    
    const toTitleCase = (str) =>
      str.replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.slice(1).toLowerCase());

    if (participants !== undefined) {
      meeting.participants = Array.isArray(participants)
        ? participants.map((p) => toTitleCase(p.trim())).filter(Boolean)
        : [];
    }

    if (agenda !== undefined) meeting.agenda = agenda.trim();
    if (status !== undefined) meeting.status = status;
    if (duration !== undefined) meeting.duration = duration;

    await meeting.save();

    res.status(200).json({
      success: true,
      data: { meeting },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete meeting and associated data
 * @route   DELETE /api/meetings/:id
 * @access  Private
 */
const deleteMeeting = async (req, res, next) => {
  try {
    const meeting = await Meeting.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    // Clean up associated resources in database
    const documents = await Document.find({ meetingId: req.params.id });

    // Clean up files from disk
    if (meeting.audioFile?.path && fs.existsSync(meeting.audioFile.path)) {
      try { fs.unlinkSync(meeting.audioFile.path); } catch (_) {}
    }
    for (const doc of documents) {
      if (doc.filePath && fs.existsSync(doc.filePath)) {
        try { fs.unlinkSync(doc.filePath); } catch (_) {}
      }
    }

    await Promise.all([
      Transcript.deleteMany({ meetingId: req.params.id }),
      MOM.deleteMany({ meetingId: req.params.id }),
      Document.deleteMany({ meetingId: req.params.id }),
      ProcessingJob.deleteMany({ meetingId: req.params.id }),
    ]);

    res.status(200).json({
      success: true,
      message: 'Meeting and associated records deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Regenerate MOM for a meeting using existing transcript
 * @route   POST /api/meetings/:id/regenerate-mom
 * @access  Private
 */
const regenerateMOM = async (req, res, next) => {
  try {
    const meeting = await Meeting.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!meeting) {
      return res.status(404).json({
        success: false,
        error: 'Meeting not found',
      });
    }

    const transcript = await Transcript.findOne({ meetingId: meeting._id });
    if (!transcript || !transcript.rawText || transcript.rawText.trim().length < 10) {
      return res.status(400).json({
        success: false,
        error: 'No valid transcript found for this meeting to regenerate MOM from.',
      });
    }

    const { getAIProvider } = require('../services/providerFactory');
    const aiProvider = getAIProvider();

    // Past context for continuity
    const pastMeetings = await Meeting.find({
      userId: meeting.userId,
      status: 'completed',
      _id: { $ne: meeting._id },
    })
      .sort({ createdAt: -1 })
      .limit(3)
      .select('_id title dateTime participants');

    let pastContext = [];
    for (const pm of pastMeetings) {
      const pastMom = await MOM.findOne({ meetingId: pm._id }).select('meetingSummary actionItems');
      if (pastMom) {
        pastContext.push({
          title: pm.title,
          participants: pm.participants,
          summary: pastMom.meetingSummary,
          actionItems: pastMom.actionItems,
        });
      }
    }

    const TeamKnowledge = require('../models/TeamKnowledge');
    const knowledgeDoc = await TeamKnowledge.findOne({ userId: meeting.userId });
    const teamKnowledge = knowledgeDoc ? knowledgeDoc.learnedContext : '';

    const momData = await aiProvider.generateMOM(meeting, transcript, { pastContext, teamKnowledge });

    // Check if error summary was returned
    if (momData.meetingSummary && momData.meetingSummary.toLowerCase().includes('gemini error')) {
      return res.status(503).json({
        success: false,
        error: momData.meetingSummary,
      });
    }

    const savedMOM = await MOM.findOneAndUpdate(
      { meetingId: meeting._id },
      {
        meetingId: meeting._id,
        ...momData,
        language: 'en',
        isEditedByUser: false,
        translations: new Map(),
      },
      { upsert: true, returnDocument: 'after' }
    );

    // Update Permanent Team Knowledge in background
    const { updateTeamKnowledge } = require('../services/ai/knowledgeService');
    updateTeamKnowledge(meeting.userId, momData, meeting._id).catch(e => console.error(e));

    // Update meeting status if needed
    if (meeting.status !== 'completed') {
      meeting.status = 'completed';
      await meeting.save();
    }

    // Auto update pre-generated PDF
    try {
      const documentService = require('../services/document/DocumentService');
      const Document = require('../models/Document');
      const pdfResult = await documentService.generatePDF(meeting, savedMOM, 'en');
      await Document.findOneAndUpdate(
        { meetingId: meeting._id, format: 'pdf' },
        {
          meetingId: meeting._id,
          momId: savedMOM._id,
          format: 'pdf',
          language: 'en',
          filePath: pdfResult.filePath,
          fileName: pdfResult.fileName,
          fileSize: pdfResult.fileSize,
          mimeType: 'application/pdf',
          updatedAt: new Date(),
        },
        { upsert: true }
      );
    } catch (pdfErr) {
      console.error(`[Regenerate MOM] Failed to update PDF for meeting ${meeting._id}:`, pdfErr.message);
    }

    // Auto sync to Master Excel Tracker
    try {
      const documentService = require('../services/document/DocumentService');
      await documentService.syncToMasterTracker(meeting, savedMOM);
    } catch (excelErr) {
      console.error(`[Regenerate MOM] Failed to sync to Master Excel:`, excelErr.message);
    }

    res.status(200).json({
      success: true,
      message: 'MOM regenerated successfully',
      data: { mom: savedMOM },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createMeeting,
  getMeetings,
  getMeetingById,
  updateMeeting,
  deleteMeeting,
  regenerateMOM,
};
