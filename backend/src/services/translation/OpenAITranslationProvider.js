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
You are a professional multilingual translator specialized in business minutes and executive documents.
Translate all text contents of the provided MOM JSON structure accurately into ${targetName}.
Keep proper names, brand names, and technical terms natural.
Ensure correct Gujarati / Hindi grammar, formal business terminology, and Unicode characters.
Return ONLY valid JSON matching the exact input JSON schema.
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
