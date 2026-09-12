const { GoogleGenAI } = require('@google/genai');
const TranslationProvider = require('./TranslationProvider');
const env = require('../../config/env');

class GeminiTranslationProvider extends TranslationProvider {
  constructor() {
    super();
    this.apiKey = env.geminiApiKey || process.env.GEMINI_API_KEY;
    if (!this.apiKey) {
      throw new Error('Gemini API Key missing for Translation');
    }
    this.ai = new GoogleGenAI({ apiKey: this.apiKey });
  }

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
4. CRITICAL: Preserve all paragraph breaks ("\\n\\n") in "meetingSummary" and "conclusion".
5. Keep person names, dates, numbers, and priorities clear and recognizable.
6. Return ONLY valid JSON matching the exact input JSON schema.

Translate this MOM to ${targetName}:
${JSON.stringify(mom, null, 2)}
`;

    const candidateModels = ['gemini-3.6-flash'];
    let lastErr;

    for (const currentModel of candidateModels) {
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const response = await this.ai.models.generateContent({
            model: currentModel,
            contents: systemPrompt,
            config: {
              responseMimeType: 'application/json',
              temperature: 0.2,
            },
          });

          const translated = JSON.parse(response.text);
          translated.language = targetLanguage;
          return translated;
        } catch (err) {
          lastErr = err;
          const isOverload = err.message?.includes('503') || err.message?.includes('429') || err.message?.toLowerCase().includes('high demand') || err.message?.toLowerCase().includes('overloaded') || err.message?.toLowerCase().includes('quota');
          
          if (isOverload && attempt < 3) {
            let waitMs = 2000 * Math.pow(2, attempt - 1);
            if (err.message?.includes('429') || err.message?.toLowerCase().includes('quota')) {
               waitMs = 25000; // Wait 25 seconds for rate limit
            }
            console.warn(`[GeminiTranslation] ${currentModel} overloaded. Retrying in ${waitMs}ms (Attempt ${attempt}/3)...`);
            await new Promise(r => setTimeout(r, waitMs));
            continue;
          } else {
            console.warn(`[GeminiTranslation] ${currentModel} failed: ${err.message}`);
            break;
          }
        }
      }
    }
    
    // ULTIMATE FALLBACK TO GROQ IF ALL GEMINI MODELS FAIL/RATE LIMIT
    console.warn('[GeminiTranslation] All Gemini models failed or rate-limited. Falling back to Groq llama-3.1-8b-instant...');
    try {
      
      const Groq = require('groq-sdk');
      const env = require('../../config/env');
      const groqClient = new Groq({ apiKey: env.groqApiKey || process.env.GROQ_API_KEY });
      
      // Dynamically fetch available model to prevent 404/Decommission errors
      const modelsPage = await groqClient.models.list();
      const activeModels = modelsPage.data.filter(m => !m.id.includes('whisper') && !m.id.includes('vision'));
      const fallbackModel = activeModels.length > 0 ? activeModels[0].id : 'mixtral-8x7b-32768';
      console.log(`[Groq Fallback] Dynamically selected model: ${fallbackModel}`);

      const gRes = await groqClient.chat.completions.create({
        model: fallbackModel,
        messages: [{ role: 'system', content: systemPrompt }],
        temperature: 0.2,
        response_format: { type: 'json_object' }
      });
      const translated = JSON.parse(gRes.choices[0]?.message?.content);
      translated.language = targetLanguage;
      return translated;
    } catch (groqErr) {
      console.error('[GeminiTranslation] Groq ultimate fallback failed:', groqErr.message);
      throw lastErr; 
    }
  }
}

module.exports = GeminiTranslationProvider;
