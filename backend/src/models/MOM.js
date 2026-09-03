const mongoose = require('mongoose');

const actionItemSchema = new mongoose.Schema({
  task: {
    type: String,
    required: true,
    trim: true,
  },
  owner: {
    type: String,
    default: '',
    trim: true,
  },
  deadline: {
    type: String,
    default: '',
    trim: true,
  },
  priority: {
    type: String,
    default: 'Medium',
  },
});

const momSchema = new mongoose.Schema(
  {
    meetingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Meeting',
      required: true,
      unique: true,
      index: true,
    },
    version: {
      type: Number,
      default: 1,
    },
    language: {
      type: String,
      default: 'en',
    },
    meetingSummary: {
      type: String,
      default: '',
      trim: true,
    },
    agenda: [
      {
        type: String,
        trim: true,
      },
    ],
    keyDiscussionPoints: [
      {
        type: String,
        trim: true,
      },
    ],
    decisions: [
      {
        type: String,
        trim: true,
      },
    ],
    actionItems: [actionItemSchema],
    pendingItems: [
      {
        type: String,
        trim: true,
      },
    ],
    risks: [
      {
        type: String,
        trim: true,
      },
    ],
    nextSteps: [
      {
        type: String,
        trim: true,
      },
    ],
    nextMeeting: {
      date: {
        type: String,
        default: '',
        trim: true,
      },
      time: {
        type: String,
        default: '',
        trim: true,
      },
    },
    conclusion: {
      type: String,
      default: '',
      trim: true,
    },
    isEditedByUser: {
      type: Boolean,
      default: false,
    },
    // Cache for translated versions so we never regenerate them multiple times
    translations: {
      type: Map,
      of: mongoose.Schema.Types.Mixed,
      default: {},
    },
    // Token usage tracking from OpenAI
    tokenUsage: {
      promptTokens: { type: Number, default: 0 },
      completionTokens: { type: Number, default: 0 },
      totalTokens: { type: Number, default: 0 },
      sttAudioSeconds: { type: Number, default: 0 },
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('MOM', momSchema);
