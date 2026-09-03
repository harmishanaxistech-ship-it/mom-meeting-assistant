/**
 * Abstract Base Class for Translation Providers
 */
class TranslationProvider {
  /**
   * Translate structured MOM to target language
   * @param {Object} mom - Structured MOM object
   * @param {string} targetLanguage - 'en' | 'gu' | 'hi'
   * @returns {Promise<Object>} Translated structured MOM
   */
  async translateMOM(mom, targetLanguage) {
    throw new Error('translateMOM method must be implemented by concrete Translation provider');
  }
}

module.exports = TranslationProvider;
