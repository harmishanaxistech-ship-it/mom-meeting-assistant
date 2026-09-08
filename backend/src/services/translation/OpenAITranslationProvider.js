const OpenAI = require('openai');
const TranslationProvider = require('./TranslationProvider');
const env = require('../../config/env');

class OpenAITranslationProvider extends TranslationProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.translation,
    });
  }

  /**
   * Translates structured MOM into target language (en, gu, hi)
   * preserves all edited fields without loss.
   */
  async translateMOM(mom, targetLanguage) {
    if (!targetLanguage || targetLanguage === mom.language) {
      return mom;
    }

    const langNames = {
      en: 'English',
      gu: 'Gujarati',
      hi: 'Hindi',
    };

    const targetName = langNames[targetLanguage] || targetLanguage;

    const systemPrompt = `
You are a professional multilingual business translator specialized in corporate minutes of meeting (MOM).
Translate all text contents of the provided MOM JSON structure into ${targetName}.

CRITICAL NATURAL BUSINESS LANGUAGE & VOCABULARY GUIDELINES:
1. DO NOT USE OVERLY PURE, OBSOLETE, OR ARCHAIC WORDS IN GUJARATI OR HINDI.
2. RETAIN COMMON EVERYDAY ENGLISH & TECH WORDS:
   - Words frequently used in daily corporate talk should be kept in English or written naturally as spoken without over-translating.
   - Examples of words to KEEP as common English terms (or write naturally in script/English):
     * "Meeting" (DO NOT translate to obscure words like અધિવેશન / સંમેલન / સભા or जटिल बैठक) -> use "Meeting" / "મીટિંગ" / "मीटिंग"
     * "Client" -> "Client" / "ક્લાયન્ટ" / "क्लाइंट"
     * "Project" -> "Project" / "પ્રોજેક્ટ" / "प्रोजेक्ट"
     * "Deadline" / "Due date" -> "Deadline" / "ડેડલાઇન" / "डेडलाइन"
     * "Team" -> "Team" / "ટીમ" / "टीम"
     * "Task" / "Action Item" -> "Task" / "ટાસ્ક" / "टास्क"
     * "Update" -> "Update" / "અપડેટ" / "अपडेट"
     * "Testing" / "QA" / "Release" / "Feature" / "Bug" / "Checklist" / "Deployment" / "Review" / "Call" / "Follow-up" / "Discussion" -> keep natural and recognizable.
3. Sentence structure and grammar must be 100% natural, modern, and fluent conversational business language understood by real professionals today.
4. CRITICAL: Preserve all paragraph breaks ("\n\n") in "meetingSummary" and "conclusion".
5. Keep person names, dates, numbers, and priorities clear and recognizable.
6. Return ONLY valid JSON matching the exact input JSON schema.
`;

    const userPrompt = `
Translate this MOM to ${targetName}:
${JSON.stringify(mom, null, 2)}
`;

    const response = await this.openai.chat.completions.create({
      model: 'gpt-4o-mini',
      temperature: 0.2,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
    });

    const translated = JSON.parse(response.choices[0].message.content);
    translated.language = targetLanguage;
    return translated;
  }
}

module.exports = OpenAITranslationProvider;
