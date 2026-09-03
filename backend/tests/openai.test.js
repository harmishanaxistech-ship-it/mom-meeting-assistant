const { getAIProvider, getTranslationProvider } = require('../src/services/providerFactory');

describe('OpenAI Live Integration Smoke Test', () => {
  it('should generate structured MOM using OpenAI GPT-4o-mini', async () => {
    const aiProvider = getAIProvider();

    const meetingData = {
      title: 'Mobile App Architecture Alignment',
      meetingType: 'Project Review',
      location: 'Conference Room A',
      participants: ['Dev Team', 'Product Lead'],
      agenda: 'Finalize stack and deliverables',
    };

    const transcriptData = {
      rawText:
        'Dev Team agreed to use Flutter with Riverpod for state management. ' +
        'Product Lead confirmed the launch date is set for next month. ' +
        'Dev Team will finish the audio recording module by this Thursday.',
      segments: [],
    };

    const mom = await aiProvider.generateMOM(meetingData, transcriptData);

    expect(mom).toBeDefined();
    expect(typeof mom.meetingSummary).toBe('string');
    expect(mom.meetingSummary.length).toBeGreaterThan(10);
    expect(Array.isArray(mom.actionItems)).toBe(true);
    expect(mom.actionItems.length).toBeGreaterThan(0);
    expect(mom.actionItems[0]).toHaveProperty('task');
  }, 25000);

  it('should translate structured MOM to Gujarati using OpenAI', async () => {
    const translationProvider = getTranslationProvider();

    const sampleMOM = {
      meetingSummary: 'The team confirmed the project launch schedule.',
      decisions: ['Use Flutter and Node.js'],
      actionItems: [{ task: 'Complete testing', owner: 'Dev Team', deadline: 'Thursday', priority: 'High' }],
      language: 'en',
    };

    const translated = await translationProvider.translateMOM(sampleMOM, 'gu');

    expect(translated).toBeDefined();
    expect(translated.language).toBe('gu');
    expect(typeof translated.meetingSummary).toBe('string');
    expect(translated.meetingSummary.length).toBeGreaterThan(5);
  }, 25000);
});
