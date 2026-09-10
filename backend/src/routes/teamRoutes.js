const express = require('express');
const router = express.Router();
const { getTeamMembers, addTeamMember, updateTeamMember, deleteTeamMember } = require('../controllers/teamController');
const { protect } = require('../middleware/auth');

router.use(protect);
router.route('/').get(getTeamMembers).post(addTeamMember);
router.route('/:id').put(updateTeamMember).delete(deleteTeamMember);

module.exports = router;
