const mongoose = require('mongoose');

const processingJobSchema = new mongoose.Schema(
  {
    meetingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Meeting',
      required: true,
      index: true,
    },
    currentStage: {
      type: String,
      enum: [
        'upload_completed',
        'transcription',
        'speaker_identification',
        'ai_analysis',
        'mom_generation',
        'completed',
        'failed',
      ],
      default: 'upload_completed',
    },
    progressPercent: {
      type: Number,
      default: 0,
    },
    stages: {
      audioUploaded: {
        completed: { type: Boolean, default: false },
        completedAt: Date,
      },
      speechRecognition: {
        completed: { type: Boolean, default: false },
        completedAt: Date,
      },
      speakerIdentification: {
        completed: { type: Boolean, default: false },
        completedAt: Date,
      },
      aiAnalysis: {
        completed: { type: Boolean, default: false },
        completedAt: Date,
      },
      momGeneration: {
        completed: { type: Boolean, default: false },
        completedAt: Date,
      },
    },
    error: {
      message: String,
      code: String,
      details: mongoose.Schema.Types.Mixed,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('ProcessingJob', processingJobSchema);
