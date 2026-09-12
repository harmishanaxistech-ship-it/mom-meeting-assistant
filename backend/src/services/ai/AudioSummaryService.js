const fs = require('fs');
const path = require('path');
const env = require('../../config/env');
const { getAIProvider } = require('../providerFactory');

class AudioSummaryService {
  constructor() {}

  /**
   * Generate concise spoken script from MOM
   */
  async generateScript(mom, meeting, teamKnowledge, language = 'en') {
    const langNames = {
      en: 'English',
      hi: 'Hindi (हिंदी)',
      gu: 'Gujarati (ગુજરાતી)',
    };

    const targetLang = langNames[language] || 'English';

    // Calculate Dynamic Length based on meeting duration
    let lengthInstruction = '';
    const durationMinutes = (meeting.duration || 0) / 60;
    if (durationMinutes > 0 && durationMinutes <= 10) {
      lengthInstruction = '- Exactly 75 to 100 words (ideal for a punchy 30-40 second audio summary since the original meeting was very short).';
    } else if (durationMinutes > 30) {
      lengthInstruction = '- Approximately 250 to 450 words (ideal for a 2-3 minute comprehensive audio summary to capture the extensive meeting points).';
    } else {
      lengthInstruction = '- Exactly 150 to 220 words (ideal for 1 to 1.5 minutes of spoken audio playback).';
    }

    let specificLangInstructions = '';
    if (language === 'hi') {
      specificLangInstructions = `
- Write in modern, natural conversational "Hinglish" / Corporate Hindi (रोजमर्रा की व्यावहारिक बिज़नेस हिंदी).
- DO NOT use pure, formal, ancient, or bookish Sanskrit Hindi words.
- FREELY use common English corporate words in Devanagari script.`;
    } else if (language === 'gu') {
      specificLangInstructions = `
- Write in natural, modern conversational Gujarati / "Gujlish" (રોજિંદી વ્યવહારુ બિઝનેસ ગુજરાતી).
- DO NOT use difficult, textbook, or overly formal Gujarati words.
- FREELY use common English business terms in Gujarati script.`;
    } else {
      specificLangInstructions = `
- Write in high-level executive English.
- Clear, punchy, conversational, and direct business tone without corporate jargon.`;
    }

    const meetingType = mom.meetingType || 'General Meeting';

    const prompt = `You are a top-tier Executive Meeting Briefing Producer.
Create a clear, engaging spoken audio summary tailored specifically for this ${meetingType.toUpperCase()} in ${targetLang}.

OBJECTIVE:
- Provide an intelligent summary that connects the meeting's agenda with what was accomplished.
- Read the 'PERMANENT TEAM KNOWLEDGE & RULES' below. Use this past knowledge to understand common sense rules and avoid misrepresenting established facts.
- **TONE MATCHING**: Deeply analyze the provided MOM. If the MOM uses simple/casual vocabulary, write the audio script in simple, conversational language. If it uses highly technical executive language, match that professional tone. DO NOT invent corporate jargon if the meeting was basic.

${teamKnowledge ? `\nPERMANENT TEAM KNOWLEDGE & RULES:\n${teamKnowledge}\n` : ''}

LENGTH:
${lengthInstruction}
- ALL crucial points from the MOM MUST be covered, scaled to fit this exact word limit seamlessly.

STRUCTURE OF THE BRIEFING:
1. Executive Hook & Context: State the meeting purpose smoothly.
2. Accomplishments: Synthesize the most critical points (avoid reading bullet lists mechanically).
3. Core Decisions: Clearly state key decisions agreed upon.
4. Action Items: Highlight crucial tasks with their respective owners in a natural narrative flow.
5. Wrap-Up: Conclude with the immediate next milestone.

LANGUAGE & VOICE RULES:
${specificLangInstructions}
- Write as smooth, continuous spoken prose for a voice narrator.
- DO NOT include markdown formatting, asterisks (*), bullets, or numbered lists.
- Every sentence must sound natural and effortless when spoken aloud.

MEETING DETAILS:
Meeting Title: ${mom.title || 'Meeting Summary'}
Meeting Type: ${meetingType}
Agenda: ${mom.agenda || 'General Review'}
Participants: ${Array.isArray(mom.participants) && mom.participants.length > 0 ? mom.participants.join(', ') : 'Team members'}

MOM DATA TO SUMMARIZE:
${JSON.stringify({
  summary: mom.meetingSummary,
  discussions: mom.keyDiscussionPoints,
  decisions: mom.decisions,
  actionItems: mom.actionItems,
  pending: mom.pendingItems
}, null, 2)}

OUTPUT EXACTLY THE SCRIPT AND NOTHING ELSE:`;

    
    const candidateModels = ['gemini-3.6-flash'];
    let lastErr;
    const { GoogleGenAI } = require('@google/genai');
    const ai = new GoogleGenAI({ apiKey: env.geminiApiKey || process.env.GEMINI_API_KEY });

    for (const currentModel of candidateModels) {
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const response = await ai.models.generateContent({
            model: currentModel,
            contents: prompt,
          });

          let script = response.text?.trim() || '';
          return script;
        } catch (err) {
          lastErr = err;
          const isOverload = err.message?.includes('503') || err.message?.includes('429') || err.message?.toLowerCase().includes('high demand') || err.message?.toLowerCase().includes('overloaded') || err.message?.toLowerCase().includes('quota');
          
          if (isOverload && attempt < 3) {
            let waitMs = 2000 * Math.pow(2, attempt - 1);
            if (err.message?.includes('429') || err.message?.toLowerCase().includes('quota')) {
               waitMs = 25000; // Wait 25 seconds for rate limit
            }
            console.warn(`[AudioSummaryService] ${currentModel} overloaded. Retrying in ${waitMs}ms (Attempt ${attempt}/3)...`);
            await new Promise(r => setTimeout(r, waitMs));
            continue;
          } else {
            console.warn(`[AudioSummaryService] ${currentModel} failed: ${err.message}`);
            break; // Try next model
          }
        }
      }
    }
    
    // ULTIMATE FALLBACK TO GROQ IF ALL GEMINI MODELS FAIL/RATE LIMIT
    console.warn('[AudioSummaryService] All Gemini models failed or rate-limited. Falling back to Groq llama-3.1-8b-instant...');
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
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.3,
      });
      return gRes.choices[0]?.message?.content?.trim() || '';
    } catch (groqErr) {
      console.error('[AudioSummaryService] Groq ultimate fallback failed:', groqErr.message);
      throw lastErr; // Throw the original Gemini error for context
    }

  }

  async _fetchNeuralTTS(script, voiceName) {
    const { MsEdgeTTS, OUTPUT_FORMAT } = require('msedge-tts');
    const tts = new MsEdgeTTS();
    await tts.setMetadata(voiceName, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    
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

  async _fetchNativeIndianTTS(script, langCode) {
    const https = require('https');
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

    const audioBuffers = [];
    for (const chunk of chunks) {
      const url = `https://translate.google.com/translate_tts?ie=UTF-8&q=${encodeURIComponent(chunk)}&tl=${langCode}&client=tw-ob`;
      
      const buffer = await new Promise((resolve, reject) => {
        https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
          if (res.statusCode !== 200) return reject(new Error(`Google TTS Error: ${res.statusCode}`));
          const data = [];
          res.on('data', (c) => data.push(c));
          res.on('end', () => resolve(Buffer.concat(data)));
        }).on('error', reject);
      });
      audioBuffers.push(buffer);
      await new Promise(r => setTimeout(r, 200));
    }
    return Buffer.concat(audioBuffers);
  }

  async textToSpeech(script, language = 'en', meetingId = 'unknown') {
    if (!script) throw new Error('Script is empty');

    const edgeVoiceMap = {
      en: 'en-IN-NeerjaNeural',
      hi: 'hi-IN-SwaraNeural',
      gu: 'gu-IN-DhwaniNeural',
    };
    
    const googleLangMap = {
      en: 'en-IN',
      hi: 'hi-IN',
      gu: 'gu-IN',
    };

    try {
      const selectedNeuralVoice = edgeVoiceMap[language] || 'en-IN-NeerjaNeural';
      console.log(`[AudioSummaryService] Synthesizing Neural Studio Voice for ${language} using ${selectedNeuralVoice}...`);
      
      const buffer = await this._fetchNeuralTTS(script, selectedNeuralVoice);
      const fileName = `audio_summary_${meetingId}_${language}_${Date.now()}.mp3`;
      const filePath = path.join(env.upload.dir, fileName);
      fs.writeFileSync(filePath, buffer);

      const wordCount = script.trim().split(/\s+/).length;
      const estimatedSeconds = Math.max(20, Math.round((wordCount / 130) * 60));

      return {
        fileName,
        audioUrl: `/uploads/${fileName}`,
        durationSeconds: estimatedSeconds,
        voice: `${language.toUpperCase()} Neural Studio Voice`,
      };
    } catch (neuralErr) {
      console.warn(`[AudioSummaryService] Neural TTS failed (${neuralErr.message}), falling back to secondary providers...`);
    }

    try {
      const code = googleLangMap[language] || 'en-IN';
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
      console.warn(`[AudioSummaryService] Google TTS failed (${nativeErr.message})`);
      throw nativeErr;
    }
  }
}

module.exports = new AudioSummaryService();
