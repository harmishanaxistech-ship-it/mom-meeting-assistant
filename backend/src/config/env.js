const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

const possibleEnvPaths = [
  path.resolve(process.cwd(), '.env'),
  path.resolve(__dirname, '../../.env'),
  path.resolve(__dirname, '../../../.env'),
];

for (const envPath of possibleEnvPaths) {
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    break;
  }
}

const useLocalDB = (process.env.USE_LOCAL_DB || 'false').toLowerCase() === 'true';

const mongodbUri = useLocalDB
  ? (process.env.MONGODB_LOCAL_URI || 'mongodb://localhost:27017/mom_assistant')
  : (process.env.MONGODB_LIVE_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/mom_assistant');

module.exports = {
  port: parseInt(process.env.PORT, 10) || 5001,
  nodeEnv: process.env.NODE_ENV || 'development',
  useLocalDB,
  mongodbUri,
  jwtSecret: process.env.JWT_SECRET || 'fallback_secret_key_mom_assistant',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  staticUser: {
    email: (process.env.STATIC_USER_EMAIL || 'user@momassistant.com').toLowerCase().trim(),
    password: process.env.STATIC_USER_PASSWORD || 'Password123!',
    name: process.env.STATIC_USER_NAME || 'Demo User',
  },
  providers: {
    stt: process.env.STT_PROVIDER || 'gemini',
    ai: process.env.AI_PROVIDER || 'gemini',
    translation: process.env.TRANSLATION_PROVIDER || 'gemini',
  },
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  groqApiKey: process.env.GROQ_API_KEY || '',

  teamMembers: (process.env.TEAM_MEMBERS || '').split(',').map(name => name.trim()).filter(name => name.length > 0),
  upload: {
    dir: path.resolve(__dirname, '../../', process.env.UPLOAD_DIR || 'uploads'),
    maxFileSizeMb: parseInt(process.env.MAX_FILE_SIZE_MB, 10) || 150,
  }
};
