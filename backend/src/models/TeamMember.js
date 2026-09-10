const mongoose = require('mongoose');

const teamMemberSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    set: val => val ? val.replace(/\b\w/g, c => c.toUpperCase()) : val
  }
}, { timestamps: true });

module.exports = mongoose.model('TeamMember', teamMemberSchema);
