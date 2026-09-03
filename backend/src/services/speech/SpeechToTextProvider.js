/**
 * Abstract Base Class for Speech-To-Text Providers
 */
class SpeechToTextProvider {
  /**
   * Transcribe an audio file into text segments
   * @param {string} audioFilePath - Local path to audio file
   * @param {Object} options - Language hint, diarization options
   * @returns {Promise<{ rawText: string, segments: Array<{ speaker: string, startTime: number, endTime: number, text: string }> }>}
   */
  async transcribe(audioFilePath, options = {}) {
    throw new Error('transcribe method must be implemented by concrete STT provider');
  }
}

module.exports = SpeechToTextProvider;
