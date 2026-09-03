const SpeechToTextProvider = require('./SpeechToTextProvider');

class MockSpeechToTextProvider extends SpeechToTextProvider {
  async transcribe(audioFilePath, options = {}) {
    // Simulate slight processing latency
    await new Promise((resolve) => setTimeout(resolve, 300));

    return {
      rawText:
        'Today we discussed the new product architecture and MVP deliverables. ' +
        'We agreed to build the Flutter app with Riverpod and Node.js with Express. ' +
        'Rohan will finish the API integration by Friday. ' +
        'Priya will verify the multilingual PDF templates.',
      segments: [
        {
          speaker: 'Speaker 1',
          startTime: 0,
          endTime: 12,
          text: 'Today we discussed the new product architecture and MVP deliverables.',
        },
        {
          speaker: 'Speaker 2',
          startTime: 13,
          endTime: 28,
          text: 'We agreed to build the Flutter app with Riverpod and Node.js with Express.',
        },
        {
          speaker: 'Speaker 1',
          startTime: 29,
          endTime: 42,
          text: 'Rohan will finish the API integration by Friday.',
        },
        {
          speaker: 'Speaker 2',
          startTime: 43,
          endTime: 55,
          text: 'Priya will verify the multilingual PDF templates.',
        },
      ],
    };
  }
}

module.exports = MockSpeechToTextProvider;
