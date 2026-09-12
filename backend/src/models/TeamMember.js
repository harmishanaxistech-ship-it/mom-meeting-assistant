const mongoose = require('mongoose');

const teamMemberSchema = new mongoose.Schema({
  companyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Company"
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User"
  },
  name: {
    type: String,
    required: true,
    
    trim: true,
    set: val => val ? val.replace(/\b\w/g, c => c.toUpperCase()) : val
  }
}, { timestamps: true });

module.exports = mongoose.model('TeamMember', teamMemberSchema);
