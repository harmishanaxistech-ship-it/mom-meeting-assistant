const mongoose = require('mongoose');

const meetingSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    meetingType: {
      type: String,
      enum: [
        'Team Meeting',
        'Project Review',
        'Client Meeting',
        'Planning Meeting',
        'General Meeting',
        'Custom',
      ],
      default: 'General Meeting',
    },
    dateTime: {
      type: Date,
      default: Date.now,
    },
    location: {
      type: String,
      default: '',
      trim: true,
    },
    participants: [
      {
        type: String,
        trim: true,
      },
    ],
    agenda: {
      type: String,
      default: '',
      trim: true,
    },
    duration: {
      type: Number, // in seconds
      default: 0,
    },
    status: {
      type: String,
      enum: [
        'created',
        'recording',
        'uploading',
        'uploaded',
        'upload_completed',
        'transcribing',
        'transcribed',
        'analyzing',
        'mom_generated',
        'completed',
        'failed',
      ],
      default: 'created',
      index: true,
    },
    audioFile: {
      filename: String,
      originalName: String,
      path: String,
      size: Number,
      mimeType: String,
      uploadedAt: Date,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Meeting', meetingSchema);
