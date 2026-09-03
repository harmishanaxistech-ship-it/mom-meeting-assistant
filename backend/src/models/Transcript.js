const mongoose = require('mongoose');

const transcriptSegmentSchema = new mongoose.Schema({
  speaker: {
    type: String,
    required: true,
    default: 'Speaker 1',
  },
  startTime: {
    type: Number, // in seconds or milliseconds
    required: true,
    default: 0,
  },
  endTime: {
    type: Number,
    required: true,
    default: 0,
  },
  text: {
    type: String,
    required: true,
    trim: true,
  },
});

const transcriptSchema = new mongoose.Schema(
  {
    meetingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Meeting',
      required: true,
      unique: true,
      index: true,
    },
    language: {
      type: String,
      default: 'en',
    },
    rawText: {
      type: String,
      default: '',
    },
    segments: [transcriptSegmentSchema],
    provider: {
      type: String,
      default: 'mock',
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Transcript', transcriptSchema);
