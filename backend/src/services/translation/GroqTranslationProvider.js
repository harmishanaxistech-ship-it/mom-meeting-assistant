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
You are an expert corporate translator specializing in professional business documents.
Translate the following Minutes of Meeting (MOM) into ${targetLangName}.

NATURAL BUSINESS VOCABULARY RULES:
1. DO NOT use overly pure, difficult, or archaic words in Gujarati or Hindi.
2. RETAIN common everyday English & corporate terminology (either directly or written phonetically in script):
   - Example: Keep "Meeting" as "Meeting" / "મીટિંગ" / "मीटिंग" (never obscure words like અધિવેશન or સભા).
   - Example: Keep words like "Client", "Project", "Deadline", "Team", "Task", "Update", "Feature", "Testing", "Bug", "Follow-up", "Checklist", "Email" natural and recognizable.
3. Keep person names, dates, and times unchanged.
4. For action items, translate task and priority clearly.
5. Preserve paragraph breaks.

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
  "otherNotes": ["..."],
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
  otherNotes: momData.otherNotes,
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
      otherNotes: parsed.otherNotes || momData.otherNotes || [],
      nextMeeting: parsed.nextMeeting || momData.nextMeeting,
      conclusion: parsed.conclusion || momData.conclusion,
      language: targetLanguage,
    };
  }
}

module.exports = GroqTranslationProvider;
