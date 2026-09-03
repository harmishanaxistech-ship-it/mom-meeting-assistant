const env = require('../config/env');
const MockSpeechToTextProvider = require('./speech/MockSpeechToTextProvider');
const OpenAISpeechToTextProvider = require('./speech/OpenAISpeechToTextProvider');
const GroqSpeechToTextProvider = require('./speech/GroqSpeechToTextProvider');

const MockAIProvider = require('./ai/MockAIProvider');
const OpenAIAIProvider = require('./ai/OpenAIAIProvider');
const GroqAIProvider = require('./ai/GroqAIProvider');

const MockTranslationProvider = require('./translation/MockTranslationProvider');
const OpenAITranslationProvider = require('./translation/OpenAITranslationProvider');
const GroqTranslationProvider = require('./translation/GroqTranslationProvider');

// Service factory following Rule 1 & Section 30-32
const getSTTProvider = () => {
  switch (env.providers.stt.toLowerCase()) {
    case 'groq':
      return new GroqSpeechToTextProvider();
    case 'openai':
      return new OpenAISpeechToTextProvider();
    case 'mock':
    default:
      return new MockSpeechToTextProvider();
  }
};

const getAIProvider = () => {
  switch (env.providers.ai.toLowerCase()) {
    case 'groq':
      return new GroqAIProvider();
    case 'openai':
      return new OpenAIAIProvider();
    case 'mock':
    default:
      return new MockAIProvider();
  }
};

const getTranslationProvider = () => {
  switch (env.providers.translation.toLowerCase()) {
    case 'groq':
      return new GroqTranslationProvider();
    case 'openai':
      return new OpenAITranslationProvider();
    case 'mock':
    default:
      return new MockTranslationProvider();
  }
};

module.exports = {
  getSTTProvider,
  getAIProvider,
  getTranslationProvider,
};
