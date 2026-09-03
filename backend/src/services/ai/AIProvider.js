/**
 * Abstract Base Class for AI Providers (MOM Generation)
 */
class AIProvider {
  /**
   * Generate structured MOM from transcript
   * @param {Object} meetingData - Meeting meta (title, type, participants, agenda)
   * @param {Object} transcriptData - Full transcript with segments
   * @returns {Promise<Object>} Structured MOM json complying with Section 33 schema
   */
  async generateMOM(meetingData, transcriptData) {
    throw new Error('generateMOM method must be implemented by concrete AI provider');
  }
}

module.exports = AIProvider;
