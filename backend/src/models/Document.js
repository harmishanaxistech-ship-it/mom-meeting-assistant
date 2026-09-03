const mongoose = require('mongoose');

const documentSchema = new mongoose.Schema(
  {
    meetingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Meeting',
      required: true,
      index: true,
    },
    momId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MOM',
      required: true,
    },
    format: {
      type: String,
      enum: ['pdf', 'docx'],
      required: true,
    },
    language: {
      type: String,
      enum: ['en', 'gu', 'hi'],
      required: true,
      default: 'en',
    },
    filePath: {
      type: String,
      required: true,
    },
    fileName: {
      type: String,
      required: true,
    },
    fileSize: {
      type: Number,
      default: 0,
    },
    mimeType: {
      type: String,
      default: 'application/octet-stream',
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Document', documentSchema);
