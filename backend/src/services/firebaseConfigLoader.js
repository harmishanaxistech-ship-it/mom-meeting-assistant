const { initializeApp, cert, getApp } = require('firebase-admin/app');
const { getRemoteConfig } = require('firebase-admin/remote-config');
const fs = require('fs');
const path = require('path');
const env = require('../config/env');

let isInitialized = false;

async function loadConfigFromFirebase() {
  try {
    const keyPath = path.resolve(process.cwd(), 'firebase-service-account.json');
    
    if (!fs.existsSync(keyPath)) {
      console.warn('[Firebase] No firebase-service-account.json found in backend root. Skipping Remote Config and using local .env keys.');
      return;
    }

    if (!isInitialized) {
      const serviceAccount = require(keyPath);
      
      if (serviceAccount.project_id === "your-project-id") {
        console.warn('[Firebase] firebase-service-account.json contains placeholder values. Please replace it with your real Firebase Service Account JSON.');
        return;
      }

      try {
        getApp();
      } catch (e) {
        initializeApp({
          credential: cert(serviceAccount)
        });
      }
      isInitialized = true;
      console.log('[Firebase] Admin SDK initialized successfully.');
    }

    console.log('[Firebase Remote Config] Fetching active template to extract API keys...');
    const template = await getRemoteConfig().getTemplate();
    const params = template.parameters || {};

    const extractValue = (keyName) => {
      if (params[keyName] && params[keyName].defaultValue && params[keyName].defaultValue.value) {
        return params[keyName].defaultValue.value;
      }
      return null;
    };

    
    const geminiKey = extractValue('GEMINI_API_KEY');
    const groqKey = extractValue('GROQ_API_KEY');
    const openaiKey = extractValue('OPENAI_API_KEY');
    const useGroqVal = extractValue('USE_GROQ');

    if (geminiKey && geminiKey.trim() !== '') {
      process.env.GEMINI_API_KEY = geminiKey;
      env.geminiApiKey = geminiKey;
      console.log('[Firebase Remote Config] Successfully injected GEMINI_API_KEY.');
    }
    
    if (groqKey && groqKey.trim() !== '') {
      process.env.GROQ_API_KEY = groqKey;
      env.groqApiKey = groqKey;
      console.log('[Firebase Remote Config] Successfully injected GROQ_API_KEY.');
    }

    if (openaiKey && openaiKey.trim() !== '') {
      process.env.OPENAI_API_KEY = openaiKey;
      env.openaiApiKey = openaiKey;
      console.log('[Firebase Remote Config] Successfully injected OPENAI_API_KEY.');
    }

    if (useGroqVal !== null) {
      process.env.USE_GROQ = useGroqVal;
      env.useGroq = useGroqVal.toString().toLowerCase() === 'true';
      console.log(`[Firebase Remote Config] Successfully injected USE_GROQ: ${env.useGroq}`);
    }
    
  } catch (error) {

    console.error('[Firebase Remote Config] Error fetching config:', error.message);
  }
}

module.exports = { loadConfigFromFirebase };
