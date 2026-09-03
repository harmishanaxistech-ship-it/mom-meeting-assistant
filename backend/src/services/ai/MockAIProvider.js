const AIProvider = require('./AIProvider');

class MockAIProvider extends AIProvider {
  async generateMOM(meetingData, transcriptData) {
    // Simulate slight processing latency
    await new Promise((resolve) => setTimeout(resolve, 400));

    return {
      meetingSummary:
        'The team aligned on the MOM Meeting Assistant project architecture, technical stack selection, and MVP roadmap milestones for Flutter and Node.js.',
      agenda: meetingData.agenda
        ? [meetingData.agenda]
        : ['Architecture Review', 'Tech Stack Finalization', 'Sprint Action Items'],
      keyDiscussionPoints: [
        'Reviewed backend framework options and confirmed Node.js with Express & MongoDB.',
        'Finalized Flutter mobile app architecture with Riverpod state management and provider abstraction.',
        'Discussed multi-language export workflow (English, Hindi, Gujarati) with Unicode fonts.',
      ],
      decisions: [
        'Adopt modular third-party provider pattern for STT and AI.',
        'Keep all API keys strictly on backend server.',
        'Generate final PDF/DOCX only from latest user-approved MOM.',
      ],
      actionItems: [
        {
          task: 'Complete API endpoints for meetings and uploads',
          owner: 'Rohan',
          deadline: 'Friday',
          priority: 'High',
        },
        {
          task: 'Implement multilingual PDF generation test',
          owner: 'Priya',
          deadline: 'Next Monday',
          priority: 'Medium',
        },
      ],
      pendingItems: ['Final vendor selection for cloud Speech-To-Text API'],
      risks: [
        'Font rendering on older mobile viewers for Gujarati/Hindi characters without embedded font',
      ],
      nextSteps: [
        'Verify end-to-end recording upload and processing flow in Phase 3 & 4',
      ],
      nextMeeting: {
        date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        time: '11:00 AM',
      },
      conclusion:
        'The foundation architecture is finalized and ready for Phase 2 implementation.',
    };
  }
}

module.exports = MockAIProvider;
