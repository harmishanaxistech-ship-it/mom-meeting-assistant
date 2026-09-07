const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const Meeting = require('../models/Meeting');
const Transcript = require('../models/Transcript');
const MOM = require('../models/MOM');
const ProcessingJob = require('../models/ProcessingJob');
const { getSTTProvider, getAIProvider } = require('../services/providerFactory');
const env = require('../config/env');
const multer = require('multer');

// Configure Multer Storage for Meeting Audio Files
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    if (!fs.existsSync(env.upload.dir)) {
      fs.mkdirSync(env.upload.dir, { recursive: true });
    }
    cb(null, env.upload.dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `meeting-${req.params.id}-${uniqueSuffix}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: env.upload.maxFileSize },
});

/**
 * @desc    Upload audio file for a meeting (Max 30 minutes duration allowed)
 * @route   POST /api/meetings/:id/upload
 * @access  Private
 */
const uploadAudio = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'Please upload an audio file',
      });
    }

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

    let durationSeconds = 0;
    // Validate Audio Duration using ffprobe (Strict limit: 30 minutes / 1800 seconds)
    try {
      const durationOut = execSync(
        `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${req.file.path}"`,
        { stdio: ['pipe', 'pipe', 'ignore'] }
      )
        .toString()
        .trim();

      durationSeconds = Math.round(parseFloat(durationOut) || 0);
      if (durationSeconds > 1800) {
        // Exceeds 30 minutes - delete uploaded file and reject
        if (fs.existsSync(req.file.path)) {
          fs.unlinkSync(req.file.path);
        }
        const mins = (durationSeconds / 60).toFixed(1);
        return res.status(400).json({
          success: false,
          error: `Selected audio is ${mins} minutes long. Only audio up to 30 minutes is allowed.`,
        });
      }
    } catch (_) {
      // If ffprobe cannot determine duration, continue
    }

    // Attach audio metadata and exact duration to Meeting
    meeting.audioFile = {
      filename: req.file.filename,
      originalName: req.file.originalname,
      mimeType: req.file.mimetype,
      size: req.file.size,
      path: req.file.path,
    };
    if (durationSeconds > 0) {
      meeting.duration = durationSeconds;
    }
    meeting.status = 'upload_completed';
    await meeting.save();

    // Create or reset ProcessingJob tracking
    let job = await ProcessingJob.findOne({ meetingId: meeting._id });
    if (!job) {
      job = await ProcessingJob.create({
        meetingId: meeting._id,
        currentStage: 'upload_completed',
        progressPercent: 20,
        stages: {
          audioUploaded: { completed: true, completedAt: new Date() },
        },
      });
    } else {
      job.currentStage = 'upload_completed';
      job.progressPercent = 20;
      job.stages.audioUploaded = { completed: true, completedAt: new Date() };
      await job.save();
    }

    res.status(200).json({
      success: true,
      message: 'Audio file uploaded successfully',
      data: {
        audioFile: meeting.audioFile,
        duration: meeting.duration,
        job,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Process meeting audio: STT -> AI MOM (ASYNC - returns 202 immediately)
 * @route   POST /api/meetings/:id/process
 * @access  Private
 *
 * WHY ASYNC: OpenAI Whisper STT + GPT-4o can take 3-5 minutes for a 7-minute audio.
 * Cloudflare Quick Tunnels timeout at 100 seconds → HTTP 524 error.
 * Fix: Respond 202 immediately, run heavy processing in background.
 * Flutter polls /processing-status every 3s and navigates when status = completed.
 */
const processMeeting = async (req, res, next) => {
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

    // Prevent double-processing
    if (meeting.status === 'transcribing' || meeting.status === 'analyzing') {
      return res.status(409).json({
        success: false,
        error: 'Meeting is already being processed',
      });
    }

    // Create or reset ProcessingJob
    let job = await ProcessingJob.findOne({ meetingId: meeting._id });
    if (!job) {
      job = await ProcessingJob.create({
        meetingId: meeting._id,
        currentStage: 'transcription',
        progressPercent: 10,
      });
    } else {
      job.currentStage = 'transcription';
      job.progressPercent = 10;
      job.error = undefined;
      await job.save();
    }

    meeting.status = 'transcribing';
    await meeting.save();

    // ✅ RESPOND IMMEDIATELY (202 Accepted) — don't wait for processing
    // Flutter's polling timer will detect completion via /processing-status
    res.status(202).json({
      success: true,
      message: 'Processing started. Poll /processing-status for updates.',
      data: { meetingId: meeting._id, status: 'transcribing' },
    });

    // ─── BACKGROUND PROCESSING (fire-and-forget) ───────────────────────────
    // Runs AFTER response is sent. No HTTP timeout applies here.
    setImmediate(async () => {
      try {
        // Stage 1: STT Transcription
        job.currentStage = 'transcription';
        job.progressPercent = 25;
        await job.save();

        const sttProvider = getSTTProvider();
        const audioPath = meeting.audioFile?.path;

        let transcriptResult;
        if (audioPath && fs.existsSync(audioPath)) {
          transcriptResult = await sttProvider.transcribe(audioPath, {
            title: meeting.title,
            agenda: meeting.agenda,
            participants: meeting.participants || [],
          });
        } else {
          transcriptResult = {
            rawText: `Discussion on ${meeting.title}. Participants: ${(meeting.participants || []).join(', ')}.`,
            segments: [{ speaker: 'Speaker 1', startTime: 0, endTime: 30, text: `Discussion on ${meeting.title}.` }],
          };
        }

        const transcript = await Transcript.findOneAndUpdate(
          { meetingId: meeting._id },
          {
            meetingId: meeting._id,
            rawText: transcriptResult.rawText,
            segments: transcriptResult.segments,
            provider: env.providers.stt,
          },
          { upsert: true, returnDocument: 'after' }
        );

        // Stage 2: STT complete, start AI analysis
        job.stages.speechRecognition = { completed: true, completedAt: new Date() };
        job.stages.speakerIdentification = { completed: true, completedAt: new Date() };
        job.currentStage = 'ai_analysis';
        job.progressPercent = 65;
        await job.save();

        meeting.status = 'analyzing';
        await meeting.save();

        // Stage 3: AI MOM Generation
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

        const aiProvider = getAIProvider();
        const momData = await aiProvider.generateMOM(meeting, transcript, { pastContext });

        job.currentStage = 'mom_generation';
        job.progressPercent = 90;
        await job.save();

        await MOM.findOneAndUpdate(
          { meetingId: meeting._id },
          { meetingId: meeting._id, ...momData, language: 'en' },
          { upsert: true }
        );

        // Stage 4: Complete
        job.stages.aiAnalysis = { completed: true, completedAt: new Date() };
        job.stages.momGeneration = { completed: true, completedAt: new Date() };
        job.currentStage = 'completed';
        job.progressPercent = 100;
        await job.save();

        meeting.status = 'completed';
        await meeting.save();

        console.log(`[Process] Meeting ${meeting._id} processed successfully.`);
      } catch (bgError) {
        console.error(`[Process] Background error for meeting ${meeting._id}:`, bgError.message);
        await Meeting.findByIdAndUpdate(meeting._id, { status: 'failed' });
        await ProcessingJob.findOneAndUpdate(
          { meetingId: meeting._id },
          { currentStage: 'failed', error: { message: bgError.message } }
        );
      }
    });
    // ────────────────────────────────────────────────────────────────────────

  } catch (error) {
    next(error);
  }
};


/**
 * @desc    Get processing status & real-time progress percentage
 * @route   GET /api/meetings/:id/processing-status
 * @access  Private
 */
const getProcessingStatus = async (req, res, next) => {
  try {
    const job = await ProcessingJob.findOne({ meetingId: req.params.id });
    const meeting = await Meeting.findById(req.params.id).select('status audioFile duration');

    res.status(200).json({
      success: true,
      data: {
        meetingStatus: meeting?.status || 'unknown', // Primary field Flutter checks
        status: meeting?.status || 'unknown',        // Legacy alias
        currentStage: job?.currentStage || 'transcription',
        progressPercent: job?.progressPercent || 0,
        duration: meeting?.duration || 0,
        error: job?.error?.message || null,
        job,
      },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  upload,
  uploadAudio,
  processMeeting,
  getProcessingStatus,
};
