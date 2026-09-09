const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

// Check and load .env from root directory, current working directory, or backend directory
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

const useGroq = (process.env.USE_GROQ || 'false').toLowerCase() === 'true';
const useLocalDB = (process.env.USE_LOCAL_DB || 'false').toLowerCase() === 'true';

// Determine MongoDB URI based on USE_LOCAL_DB toggle
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
  useGroq,
  providers: {
    stt: useGroq ? 'groq' : (process.env.STT_PROVIDER || 'openai'),
    ai: useGroq ? 'groq' : (process.env.AI_PROVIDER || 'openai'),
    translation: useGroq ? 'groq' : (process.env.TRANSLATION_PROVIDER || 'openai'),
  },
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  openaiApiKey: process.env.OPENAI_API_KEY || '',
  groqApiKey: process.env.GROQ_API_KEY || '',
  apiKeys: {
    stt: useGroq ? process.env.GROQ_API_KEY : (process.env.STT_API_KEY || process.env.OPENAI_API_KEY || ''),
    ai: useGroq ? process.env.GROQ_API_KEY : (process.env.AI_API_KEY || process.env.OPENAI_API_KEY || ''),
    translation: useGroq ? process.env.GROQ_API_KEY : (process.env.TRANSLATION_API_KEY || process.env.OPENAI_API_KEY || ''),
  },
  upload: {
    dir: path.resolve(__dirname, '../../', process.env.UPLOAD_DIR || 'uploads'),
    maxFileSizeMb: parseInt(process.env.MAX_FILE_SIZE_MB, 10) || 150,
  }
};
