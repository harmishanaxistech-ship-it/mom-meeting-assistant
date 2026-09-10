const TeamMember = require('../models/TeamMember');
const env = require('../config/env');

const seedTeamMembers = async () => {
  try {
    const count = await TeamMember.countDocuments();
    if (count === 0 && env.teamMembers && env.teamMembers.length > 0) {
      console.log('Seeding initial team members from .env...');
      const docs = env.teamMembers.map(name => ({ name }));
      await TeamMember.insertMany(docs);
      console.log('Successfully seeded team members.');
    }
  } catch (error) {
    console.error('Error seeding team members:', error);
  }
};

module.exports = seedTeamMembers;
