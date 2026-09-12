const MockSpeechToTextProvider = require('./speech/MockSpeechToTextProvider');
const GeminiSpeechToTextProvider = require('./speech/GeminiSpeechToTextProvider');

const MockAIProvider = require('./ai/MockAIProvider');
const GeminiAIProvider = require('./ai/GeminiAIProvider');

const MockTranslationProvider = require('./translation/MockTranslationProvider');
const GeminiTranslationProvider = require('./translation/GeminiTranslationProvider');

const env = require('../config/env');

const getSTTProvider = () => {
  if (env.providers.stt.toLowerCase() === 'mock') {
    return new MockSpeechToTextProvider();
  }
  return new GeminiSpeechToTextProvider();
};

const getAIProvider = () => {
  if (env.providers.ai.toLowerCase() === 'mock') {
    return new MockAIProvider();
  }
  return new GeminiAIProvider();
};

const getTranslationProvider = () => {
  if (env.providers.translation.toLowerCase() === 'mock') {
    return new MockTranslationProvider();
  }
  return new GeminiTranslationProvider();
};

module.exports = {
  getSTTProvider,
  getAIProvider,
  getTranslationProvider,
};
