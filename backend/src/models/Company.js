const mongoose = require('mongoose');

const companySchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Please add a company name'],
    trim: true,
  },
  logoUrl: { type: String, default: "" },

  minAppVersion: { type: String, default: "1.0.0" },
  updateUrl: { type: String, default: "https://noteaxapi.anaxistech.com/uploads/app-release.apk" },

  themeColor: {
    type: String,
    default: '#1E3A8A',
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  }
});

module.exports = mongoose.model('Company', companySchema);
