const TeamMember = require('../models/TeamMember');

// Get all team members
exports.getTeamMembers = async (req, res, next) => {
  try {
    const query = {};
    if (req.user.companyId) {
      query.companyId = req.user.companyId;
    } else {
      query.userId = req.user._id;
    }
    const members = await TeamMember.find(query).sort({ name: 1 });
    // Return array of strings to match existing structure, or array of objects
    res.status(200).json({ success: true, data: members });
  } catch (err) {
    next(err);
  }
};

// Add new team member
exports.addTeamMember = async (req, res, next) => {
  try {
    const { name } = req.body;
    if (!name) return res.status(400).json({ success: false, error: 'Name is required' });
    
    let member = await TeamMember.findOne({ name: { $regex: new RegExp(`^${name}$`, 'i') }, $or: [{companyId: req.user.companyId}, {userId: req.user._id}] });
    if (member) return res.status(400).json({ success: false, error: 'Team member already exists' });

    member = await TeamMember.create({ name, companyId: req.user.companyId || null, userId: req.user._id });
    res.status(201).json({ success: true, data: member });
  } catch (err) {
    next(err);
  }
};

// Update team member
exports.updateTeamMember = async (req, res, next) => {
  try {
    const { name } = req.body;
    const member = await TeamMember.findByIdAndUpdate(req.params.id, { name }, { new: true, runValidators: true });
    if (!member) return res.status(404).json({ success: false, error: 'Team member not found' });
    res.status(200).json({ success: true, data: member });
  } catch (err) {
    next(err);
  }
};

// Delete team member
exports.deleteTeamMember = async (req, res, next) => {
  try {
    const member = await TeamMember.findByIdAndDelete(req.params.id);
    if (!member) return res.status(404).json({ success: false, error: 'Team member not found' });
    res.status(200).json({ success: true, data: {} });
  } catch (err) {
    next(err);
  }
};
