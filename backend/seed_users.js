require('dotenv').config({ path: '.env' });
const mongoose = require('mongoose');
const env = require('./src/config/env');
const User = require('./src/models/User');
const Company = require('./src/models/Company');

const seed = async () => {
  try {
    await mongoose.connect(env.mongodbUri);
    
    // Fetch companies
    const skala = await Company.findOne({ name: 'SKALA' });
    const nobesity = await Company.findOne({ name: 'NOBESITY' });

    if (!skala || !nobesity) {
      console.error('Companies not found in DB!');
      process.exit(1);
    }

    const users = [
      {
        name: 'Skala User',
        email: 'user@skala.com',
        password: 'Password@123',
        companyId: skala._id
      },
      {
        name: 'Nobesity User',
        email: 'user@nobesity.com',
        password: 'Password@123',
        companyId: nobesity._id
      }
    ];

    for (const u of users) {
      const existing = await User.findOne({ email: u.email });
      if (existing) {
        existing.password = u.password; // will trigger re-hash if modified
        existing.companyId = u.companyId;
        await existing.save();
        console.log(`Updated existing user: ${u.email}`);
      } else {
        await User.create(u);
        console.log(`Created new user: ${u.email}`);
      }
    }
    
    console.log('User seed complete.');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
};

seed();
