require('dotenv').config({ path: '.env' });
const mongoose = require('mongoose');
const env = require('./src/config/env');
const Company = require('./src/models/Company');

const seed = async () => {
  try {
    await mongoose.connect(env.mongodbUri);
    const baseUrl = 'https://thinness-embroider-gizzard.ngrok-free.dev';

    await Company.updateOne({ name: 'SKALA' }, {
      $set: { logoUrl: `${baseUrl}/uploads/skala.png` }
    });

    await Company.updateOne({ name: 'NOBESITY' }, {
      $set: { logoUrl: `${baseUrl}/uploads/nobesity.png` }
    });

    console.log('Update logoUrls set to ngrok local backend paths.');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
};

seed();
