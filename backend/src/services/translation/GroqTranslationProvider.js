const Groq = require('groq-sdk');
const TranslationProvider = require('./TranslationProvider');
const env = require('../../config/env');

class GroqTranslationProvider extends TranslationProvider {
  constructor() {
    super();
    this.groq = new Groq({
      apiKey: env.groqApiKey,
    });
  }

  /**
   * Translates a structured MOM to target language (English, Hindi, or Gujarati) using Groq
   */
  async translateMOM(momData, targetLanguage) {
    const languageNames = {
      en: 'English',
      hi: 'Hindi',
      gu: 'Gujarati',
    };

    const targetLangName = languageNames[targetLanguage] || targetLanguage;

    const prompt = `
You are an expert translator specializing in professional business documents.
Translate the following Minutes of Meeting (MOM) into ${targetLangName}.
Translate all text content (summary, agenda, discussion points, decisions, tasks, conclusions).
For action items, translate task and priority (e.g. High -> उच्च / ઉચ્ચ) accurately. Keep person names and dates unchanged.

Return ONLY valid JSON matching this exact structure with no markdown ticks:
{
  "meetingSummary": "...",
  "agenda": ["..."],
  "keyDiscussionPoints": ["..."],
  "decisions": ["..."],
  "actionItems": [
    {
      "task": "...",
      "owner": "...",
      "deadline": "...",
      "priority": "..."
    }
  ],
  "pendingItems": ["..."],
  "risks": ["..."],
  "nextSteps": ["..."],
  "nextMeeting": {
    "date": "...",
    "time": "..."
  },
  "conclusion": "..."
}

MOM data to translate:
${JSON.stringify({
  meetingSummary: momData.meetingSummary,
  agenda: momData.agenda,
  keyDiscussionPoints: momData.keyDiscussionPoints,
  decisions: momData.decisions,
  actionItems: momData.actionItems,
  pendingItems: momData.pendingItems,
  risks: momData.risks,
  nextSteps: momData.nextSteps,
  nextMeeting: momData.nextMeeting,
  conclusion: momData.conclusion,
})}
`;

    const chatCompletion = await this.groq.chat.completions.create({
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
      model: 'openai/gpt-oss-120b',
      temperature: 0.3,
      max_completion_tokens: 2048,
      top_p: 1,
      stream: false,
    });

    let raw = chatCompletion.choices[0]?.message?.content || '{}';
    raw = raw.replace(/```json/g, '').replace(/```/g, '').trim();

    const parsed = JSON.parse(raw);

    return {
      meetingSummary: parsed.meetingSummary || momData.meetingSummary,
      agenda: parsed.agenda || momData.agenda,
      keyDiscussionPoints: parsed.keyDiscussionPoints || momData.keyDiscussionPoints,
      decisions: parsed.decisions || momData.decisions,
      actionItems: parsed.actionItems || momData.actionItems,
      pendingItems: parsed.pendingItems || momData.pendingItems,
      risks: parsed.risks || momData.risks,
      nextSteps: parsed.nextSteps || momData.nextSteps,
      nextMeeting: parsed.nextMeeting || momData.nextMeeting,
      conclusion: parsed.conclusion || momData.conclusion,
      language: targetLanguage,
    };
  }
}

module.exports = GroqTranslationProvider;
