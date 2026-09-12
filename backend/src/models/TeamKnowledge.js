const mongoose = require('mongoose');

const teamKnowledgeSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
  learnedContext: { type: String, default: '' },
  lastUpdatedMeeting: { type: mongoose.Schema.Types.ObjectId, ref: 'Meeting' }
}, { timestamps: true });

module.exports = mongoose.model('TeamKnowledge', teamKnowledgeSchema);
