require('dotenv').config({ path: '.env' });
const mongoose = require('mongoose');
const env = require('./src/config/env');
const Company = require('./src/models/Company');

const seed = async () => {
  try {
    await mongoose.connect(env.mongodbUri);
    const baseUrl = 'https://noteaxapi.anaxistech.com'; // or ngrok, but they use noteaxapi for prod

    await Company.updateOne({ name: 'SKALA' }, {
      $set: { updateUrl: `${baseUrl}/uploads/skala-latest.apk` }
    });

    await Company.updateOne({ name: 'NOBESITY' }, {
      $set: { updateUrl: `${baseUrl}/uploads/nobesity-latest.apk` }
    });

    console.log('Update URLs set to local backend APK paths.');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
};

seed();
