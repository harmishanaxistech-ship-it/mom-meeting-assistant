require('dotenv').config({ path: '.env' });
const mongoose = require('mongoose');
const env = require('./src/config/env');
const Company = require('./src/models/Company');

const seed = async () => {
  try {
    await mongoose.connect(env.mongodbUri);
    console.log('MongoDB Connected to', env.mongodbUri);

    const baseUrl = 'https://noteaxapi.anaxistech.com'; 
    
    const companies = [
      {
        name: 'SKALA',
        themeColor: '#3B82F6',
        logoUrl: `${baseUrl}/uploads/skala.png`
      },
      {
        name: 'NOBESITY',
        themeColor: '#10B981',
        logoUrl: `${baseUrl}/uploads/nobesity.png`
      }
    ];

    for (const comp of companies) {
      const existing = await Company.findOne({ name: comp.name });
      if (existing) {
        existing.logoUrl = comp.logoUrl;
        existing.themeColor = comp.themeColor;
        await existing.save();
        console.log(`Updated existing company: ${comp.name}`);
      } else {
        await Company.create(comp);
        console.log(`Created new company: ${comp.name}`);
      }
    }
    
    console.log('Seed complete.');
    process.exit(0);
  } catch (error) {
    console.error('Seed Error:', error);
    process.exit(1);
  }
};

seed();
