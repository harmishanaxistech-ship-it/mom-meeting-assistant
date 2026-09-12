const Company = require('../models/Company');

exports.getCompanyByCode = async (req, res) => {
  try {
    const { code } = req.params;
    // For simplicity, we assume the 'name' or a specific 'code' field is used. Let's use name for now.
    const company = await Company.findOne({ name: new RegExp('^' + code + '$', 'i') });
    
    if (!company) {
      return res.status(404).json({ success: false, error: 'Company not found' });
    }

    res.status(200).json({ success: true, data: company });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};
