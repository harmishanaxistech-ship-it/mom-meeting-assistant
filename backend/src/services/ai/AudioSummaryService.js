const fs = require('fs');
const path = require('path');
const OpenAI = require('openai');
const env = require('../../config/env');
const { getAIProvider } = require('../providerFactory');

class AudioSummaryService {
  constructor() {
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.stt,
    });
  }

  /**
   * Generate concise 1-2 min spoken script (~150-250 words) from MOM
   * in English, Hindi, or Gujarati.
   */
  async generateScript(mom, language = 'en') {
    const langNames = {
      en: 'English',
      hi: 'Hindi (हिंदी)',
      gu: 'Gujarati (ગુજરાતી)',
    };

    const targetLang = langNames[language] || 'English';

    let specificLangInstructions = '';
    if (language === 'hi') {
      specificLangInstructions = `
- Write in modern, conversational business Hindi (सहज और व्यावहारिक कॉर्पोरेट हिंदी).
- DO NOT use overly complex, archaic, or bookish Sanskritized words.
- Use regular, widely spoken corporate terms (e.g., 'मीटिंग' instead of 'अधिवेशन', 'क्लाइंट', 'प्रोजेक्ट', 'डेडलाइन', 'टास्क', 'अपडेट', 'टीम', 'डिस्कशन').
- Tone: Crisp, confident, clear, and engaging like a modern podcast or executive audio presenter.`;
    } else if (language === 'gu') {
      specificLangInstructions = `
- Write in modern, natural, conversational business Gujarati (સરળ અને વ્યવહારુ ગુજરાતી).
- DO NOT use overly pure, difficult, or archaic words (e.g., use 'મીટિંગ' instead of 'સભા/અધિવેશન', use 'ક્લાયન્ટ', 'પ્રોજેક્ટ', 'ડેડલાઇન', 'ટાસ્ક', 'અપડેટ', 'ટીમ', 'ચર્ચા').
- Tone: Warm, clear, friendly, and professional like a modern corporate podcast narrator.`;
    } else {
      specificLangInstructions = `
- Write in natural, executive-grade conversational English.
- Clear, punchy, high-impact business tone.`;
    }

    const prompt = `You are an executive audio briefing producer.
Transform the following Minutes of Meeting (MOM) into a concise, engaging spoken audio briefing in ${targetLang}.

LENGTH REQUIREMENTS:
- Exactly 150 to 230 words (ideal for 1 to 1.5 minutes of spoken playback).
- Clear, punchy, high-impact tone.

KEY CONTENT TO COVER:
1. One-sentence opening: meeting title, main objective.
2. 2-3 sentences covering the core topics and critical discussions.
3. Key decisions made.
4. Top action items with assignees and deadlines.
5. Final wrap-up and immediate next milestone.

LANGUAGE & VOICE RULES:
${specificLangInstructions}
- Write as continuous spoken prose for a voiceover narrator.
- DO NOT include markdown formatting, bold marks (**), bullet characters, numbered lists (1, 2), asterisks (*), or timestamps.
- Make every sentence flow naturally when spoken aloud.

MOM DATA:
Title: ${mom.title || 'Meeting Summary'}
Executive Summary: ${mom.meetingSummary || ''}
Key Points: ${(mom.keyDiscussionPoints || []).slice(0, 8).join('; ')}
Decisions: ${(mom.decisions || []).join('; ')}
Action Items: ${(mom.actionItems || []).map((a) => `${a.task} assigned to ${a.owner || 'team'}`).join('; ')}
Next Steps: ${(mom.nextSteps || []).join('; ')}

Return ONLY the spoken narrative text.`;

    try {
      const response = await this.openai.chat.completions.create({
        model: 'gpt-4o-mini',
        temperature: 0.3,
        messages: [{ role: 'user', content: prompt }],
      });

      const script = response.choices[0]?.message?.content?.trim() || '';
      return script;
    } catch (err) {
      console.error('[AudioSummaryService] generateScript error:', err.message);
      throw err;
    }
  }

  /**
   * High-fidelity Neural Studio TTS for Indian regional languages and Indian English.
   * Uses Microsoft Neural Voice models (e.g. gu-IN-DhwaniNeural, hi-IN-SwaraNeural, en-IN-NeerjaNeural).
   */
  async _fetchNeuralTTS(script, voiceName) {
    const { MsEdgeTTS, OUTPUT_FORMAT } = require('msedge-tts');
    const tts = new MsEdgeTTS();
    await tts.setMetadata(voiceName, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);

    // Clean script of any residual markdown or bullet points
    const cleanScript = script
      .replace(/[*_#`~[\]]/g, '')
      .replace(/\n\s*\n/g, '\n')
      .trim();

    const { audioStream } = tts.toStream(cleanScript);
    const chunks = [];

    return new Promise((resolve, reject) => {
      audioStream.on('data', (d) => chunks.push(d));
      audioStream.on('end', () => resolve(Buffer.concat(chunks)));
      audioStream.on('error', reject);
    });
  }

  /**
   * Helper to synthesize native Indian speech using Google's Neural Indian voice endpoint (fallback)
   */
  async _fetchNativeIndianTTS(script, langCode) {
    const https = require('https');

    // Split text into natural sentence chunks of <= 180 chars for clean stream chunking
    const sentences = script.replace(/([.?!।\n]+)/g, '$1|').split('|').map((s) => s.trim()).filter((s) => s.length > 0);
    const chunks = [];
    let currentChunk = '';

    for (const s of sentences) {
      if ((currentChunk + ' ' + s).trim().length <= 180) {
        currentChunk = (currentChunk + ' ' + s).trim();
      } else {
        if (currentChunk.length > 0) chunks.push(currentChunk);
        currentChunk = s;
      }
    }
    if (currentChunk.length > 0) chunks.push(currentChunk);

    const buffers = [];

    for (const chunk of chunks) {
      const url = `https://translate.google.com/translate_tts?ie=UTF-8&q=${encodeURIComponent(chunk)}&tl=${langCode}&client=tw-ob`;
      const buf = await new Promise((resolve, reject) => {
        https
          .get(
            url,
            {
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                Referer: 'https://translate.google.com/',
              },
            },
            (res) => {
              if (res.statusCode !== 200) {
                return reject(new Error(`TTS request returned status ${res.statusCode}`));
              }
              const data = [];
              res.on('data', (c) => data.push(c));
              res.on('end', () => resolve(Buffer.concat(data)));
            }
          )
          .on('error', reject);
      });
      buffers.push(buf);
    }

    return Buffer.concat(buffers);
  }

  /**
   * Converts script text to MP3 audio using Studio Neural Voice
   * - Gujarati (gu): Dhwani Neural Studio Voice (gu-IN-DhwaniNeural)
   * - Hindi (hi): Swara Neural Studio Voice (hi-IN-SwaraNeural)
   * - English (en): Neerja Indian English Neural Studio Voice (en-IN-NeerjaNeural)
   */
  async textToSpeech(script, language = 'en', meetingId) {
    const neuralVoiceMap = {
      gu: 'gu-IN-DhwaniNeural',
      hi: 'hi-IN-SwaraNeural',
      en: 'en-IN-NeerjaNeural',
    };

    const voiceLabels = {
      gu: 'ગુજરાતી Dhwani Neural Voice',
      hi: 'हिंदी Swara Neural Voice',
      en: 'Indian English Neerja Neural Voice',
    };

    const selectedNeuralVoice = neuralVoiceMap[language] || 'en-IN-NeerjaNeural';

    // 1. Primary: High-fidelity Microsoft Neural Studio Voice
    try {
      console.log(`[AudioSummaryService] Synthesizing Neural Studio Voice for ${language} using ${selectedNeuralVoice}...`);
      const buffer = await this._fetchNeuralTTS(script, selectedNeuralVoice);

      if (buffer && buffer.length > 500) {
        const fileName = `audio_summary_${meetingId}_${language}_${Date.now()}.mp3`;
        const filePath = path.join(env.upload.dir, fileName);
        fs.writeFileSync(filePath, buffer);

        const wordCount = script.trim().split(/\s+/).length;
        const estimatedSeconds = Math.max(20, Math.round((wordCount / 130) * 60));

        return {
          fileName,
          audioUrl: `/uploads/${fileName}`,
          durationSeconds: estimatedSeconds,
          voice: voiceLabels[language] || 'Neural Voice',
        };
      }
    } catch (neuralErr) {
      console.warn(`[AudioSummaryService] Neural TTS failed (${neuralErr.message}), falling back to secondary providers...`);
    }

    // 2. Secondary fallback: Google Native TTS
    try {
      const langCodeMap = { gu: 'gu', hi: 'hi', en: 'en-in' };
      const code = langCodeMap[language] || 'en-in';
      console.log(`[AudioSummaryService] Fallback to Google TTS (${code})...`);
      const buffer = await this._fetchNativeIndianTTS(script, code);

      const fileName = `audio_summary_${meetingId}_${language}_${Date.now()}.mp3`;
      const filePath = path.join(env.upload.dir, fileName);
      fs.writeFileSync(filePath, buffer);

      const wordCount = script.trim().split(/\s+/).length;
      const estimatedSeconds = Math.max(20, Math.round((wordCount / 130) * 60));

      return {
        fileName,
        audioUrl: `/uploads/${fileName}`,
        durationSeconds: estimatedSeconds,
        voice: `${language.toUpperCase()} Native Voice`,
      };
    } catch (nativeErr) {
      console.warn(`[AudioSummaryService] Google TTS failed (${nativeErr.message}), falling back to OpenAI HD voice...`);
    }

    // 3. Final Fallback: OpenAI TTS HD
    try {
      const voiceMap = {
        en: 'alloy',
        hi: 'nova',
        gu: 'shimmer',
      };

      const selectedVoice = voiceMap[language] || 'alloy';

      const mp3 = await this.openai.audio.speech.create({
        model: 'tts-1-hd',
        voice: selectedVoice,
        input: script,
        speed: 0.95,
      });

      const buffer = Buffer.from(await mp3.arrayBuffer());
      const fileName = `audio_summary_${meetingId}_${language}_${Date.now()}.mp3`;
      const filePath = path.join(env.upload.dir, fileName);
      fs.writeFileSync(filePath, buffer);

      const wordCount = script.trim().split(/\s+/).length;
      const estimatedSeconds = Math.max(20, Math.round((wordCount / 130) * 60));

      return {
        fileName,
        audioUrl: `/uploads/${fileName}`,
        durationSeconds: estimatedSeconds,
        voice: `${selectedVoice.charAt(0).toUpperCase() + selectedVoice.slice(1)} (HD Voice)`,
      };
    } catch (err) {
      console.error('[AudioSummaryService] textToSpeech all fallbacks failed:', err.message);
      throw err;
    }
  }
}

module.exports = new AudioSummaryService();
