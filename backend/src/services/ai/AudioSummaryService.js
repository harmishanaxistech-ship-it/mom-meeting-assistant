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
- Write in modern, natural conversational "Hinglish" / Corporate Hindi (रोजमर्रा की व्यावहारिक बिज़नेस हिंदी).
- DO NOT use pure, formal, ancient, or bookish Sanskrit Hindi words (e.g. NEVER use 'अधिवेशन', 'प्रतिभागियों', 'दायित्व', 'कार्यवाही', 'कार्यान्वयन', 'निष्कर्ष').
- FREELY use common English corporate words in Devanagari script (e.g. 'मीटिंग', 'डिस्कशन', 'प्रोजेक्ट', 'क्लाइंट', 'टीम', 'डेडलाइन', 'टास्क', 'अपडेट', 'फीडबैक', 'डिसीजन', 'प्लान', 'इश्यू', 'सॉल्यूशन', 'नेक्स्ट स्टेप्स', 'रिव्यू', 'स्टेटस', 'फॉलो-अप').
- Tone: High-level executive summary, very crisp, natural, like a modern CXO briefing podcast.`;
    } else if (language === 'gu') {
      specificLangInstructions = `
- Write in natural, modern conversational Gujarati / "Gujlish" (રોજિંદી વ્યવહારુ બિઝનેસ ગુજરાતી).
- DO NOT use difficult, textbook, or overly formal Gujarati words (e.g. NEVER use 'અધિવેશન', 'સભાજનો', 'કામગીરી સંભાળનાર', 'સમાપન').
- FREELY use common English business terms in Gujarati script (e.g. 'મીટિંગ', 'ડિસ્કશન', 'પ્રોજેક્ટ', 'ક્લાયન્ટ', 'ટીમ', 'ડેડલાઇન', 'ટાસ્ક', 'અપડેટ', 'ફીડબેક', 'ડિસિઝન', 'પ્લાન', 'ઇશ્યૂ', 'સોલ્યુશન', 'નેક્સ્ટ સ્ટેપ્સ', 'રિવ્યૂ', 'સ્ટેટસ', 'ફોલો-અપ').
- Tone: High-level executive briefing, warm, friendly, clear, and professional.`;
    } else {
      specificLangInstructions = `
- Write in high-level executive English.
- Clear, punchy, conversational, and direct business tone without corporate jargon.`;
    }

    const meetingType = mom.meetingType || 'General Meeting';

    // Dynamic customization based on meeting type:
    let meetingTypeContext = '';
    if (meetingType === 'Client Meeting') {
      meetingTypeContext = `
- This is a CLIENT MEETING.
- Focus heavily on client requirements, deliverables agreed upon, expectations set, feedback received, and next review/demo milestones.`;
    } else if (meetingType === 'Project Review') {
      meetingTypeContext = `
- This is a PROJECT REVIEW MEETING.
- Focus on project progress against targets, blockers/challenges identified, engineering/design decisions made, and upcoming sprint or release deadlines.`;
    } else if (meetingType === 'Team Meeting') {
      meetingTypeContext = `
- This is an INTERNAL TEAM MEETING / SYNC.
- Focus on team alignment, key work updates, cross-functional dependencies, task ownership, and priority items for the week.`;
    } else if (meetingType === 'Planning Meeting') {
      meetingTypeContext = `
- This is a STRATEGIC PLANNING / SPRINT PLANNING MEETING.
- Focus on strategic goals, roadmap priorities, resource allocation, key decisions on scope, and planned milestones.`;
    } else {
      meetingTypeContext = `
- Focus on high-level outcomes, primary topics discussed, key decisions made, and follow-up action items.`;
    }

    const prompt = `You are a top-tier Executive Meeting Briefing Producer.
Create a high-level, clear, and engaging spoken audio summary (1 to 1.5 minutes) tailored specifically for this ${meetingType.toUpperCase()} in ${targetLang}.

OBJECTIVE:
- Provide an intelligent, high-level summary that compares and connects the meeting's agenda/type with what was actually accomplished.
- Frame the summary from the perspective of an executive briefing: Why was this meeting held, what major conclusions were reached, and what are the critical next moves?

${meetingTypeContext}

LENGTH:
- Exactly 150 to 220 words (ideal for 1 to 1.5 minutes of spoken audio playback).

STRUCTURE OF THE BRIEFING:
1. Executive Hook & Context: State the meeting purpose and type in 1-2 smooth, punchy sentences.
2. High-Level Accomplishments & Discussions: Synthesize the 2-3 most critical points discussed (avoid reading bullet lists mechanically; synthesize the insights).
3. Core Decisions & Strategic Agreements: Clearly state the key decisions agreed upon by the team/clients.
4. Action Items & Accountability: Highlight the most crucial tasks with their respective owners and deadlines in natural narrative flow.
5. Forward-Looking Wrap-Up: Conclude with the immediate next milestone or upcoming checkpoint.

LANGUAGE & VOICE RULES:
${specificLangInstructions}
- Write as smooth, continuous spoken prose for a voice narrator.
- DO NOT include markdown formatting, bold marks (**), asterisks (*), bullets, numbered lists (1., 2.), or brackets.
- Every sentence must sound natural, polished, and effortless when spoken aloud.

MEETING DETAILS:
Meeting Title: ${mom.title || 'Meeting Summary'}
Meeting Type: ${meetingType}
Agenda / Objective: ${mom.agenda || 'General Review & Strategy'}
Participants: ${Array.isArray(mom.participants) && mom.participants.length > 0 ? mom.participants.join(', ') : 'Team members'}
Executive Summary: ${mom.meetingSummary || ''}
Key Discussions: ${(mom.keyDiscussionPoints || []).slice(0, 8).join('; ')}
Key Decisions: ${(mom.decisions || []).join('; ')}
Action Items: ${(mom.actionItems || []).map((a) => `${a.task} (${a.owner || 'team'} by ${a.deadline || 'upcoming'})`).join('; ')}
Next Steps & Milestones: ${(mom.nextSteps || []).join('; ')}

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
