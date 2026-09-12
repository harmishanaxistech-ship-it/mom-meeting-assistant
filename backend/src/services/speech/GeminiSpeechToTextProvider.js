const fs = require('fs');
const { GoogleGenAI } = require('@google/genai');
const env = require('../../config/env');
const path = require('path');

class GeminiSpeechToTextProvider {
  constructor() {
    this.apiKey = env.geminiApiKey || process.env.GEMINI_API_KEY;
    if (!this.apiKey) {
      throw new Error('Gemini API Key missing for STT');
    }
    this.ai = new GoogleGenAI({ apiKey: this.apiKey });
  }

  _getMimeType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    if (ext === '.m4a') return 'audio/mp4';
    if (ext === '.mp4') return 'video/mp4';
    if (ext === '.wav') return 'audio/wav';
    if (ext === '.ogg') return 'audio/ogg';
    if (ext === '.webm') return 'audio/webm';
    return 'audio/mpeg';
  }

  async transcribe(audioFilePath, options = {}) {
    if (!fs.existsSync(audioFilePath)) {
      throw new Error(`Audio file not found: ${audioFilePath}`);
    }

    console.log(`[STT Gemini] Extracting and transcribing audio using native Gemini Audio pipeline...`);
    const mimeType = this._getMimeType(audioFilePath);
    const audioBytes = fs.readFileSync(audioFilePath).toString('base64');

    const prompt = `You are an elite bilingual transcriber specializing in regional Indian languages.
Listen to the attached audio file. The audio may be a mix of English, Hindi, and Gujarati.
Your task is to transcribe the audio into a single, cohesive English transcript.
- If the speaker speaks in Hindi or Gujarati, TRANSLATE it accurately to English in the transcript.
- If the speaker speaks in English, transcribe it verbatim.
- DO NOT summarize the meeting. I need the full verbatim conversational transcript (translated to English).
- Do not include speaker labels (e.g. "Speaker 1:") unless you are absolutely sure of the voices.

Output ONLY the raw English text.`;

    
    const candidateModels = ['gemini-3.6-flash'];
    let lastErr;

    for (const currentModel of candidateModels) {
      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const response = await this.ai.models.generateContent({
            model: currentModel,
            contents: [
              {
                role: 'user',
                parts: [
                  {
                    inlineData: {
                      data: audioBytes,
                      mimeType: mimeType
                    }
                  },
                  {
                    text: prompt
                  }
                ]
              }
            ]
          });

          const transcript = response.text.trim();
          console.log(`[STT Gemini] Successfully generated native translated transcript (${transcript.length} chars) using ${currentModel}`);

          return {
            rawText: transcript,
            segments: [{
              speaker: 'Speaker',
              startTime: 0,
              endTime: 0,
              text: transcript,
            }],
            language: 'en',
            provider: currentModel,
          };
        } catch (err) {
          lastErr = err;
          const isOverload = err.message?.includes('503') || err.message?.includes('429') || err.message?.toLowerCase().includes('high demand') || err.message?.toLowerCase().includes('overloaded') || err.message?.toLowerCase().includes('quota');
          
          if (isOverload && attempt < 3) {
            let waitMs = 2000 * Math.pow(2, attempt - 1);
            if (err.message?.includes('429') || err.message?.toLowerCase().includes('quota')) {
               waitMs = 25000; // Wait 25 seconds for rate limit
            }
            console.warn(`[STT Gemini] ${currentModel} overloaded. Retrying in ${waitMs}ms (Attempt ${attempt}/3)...`);
            await new Promise(r => setTimeout(r, waitMs));
            continue;
          } else {
            console.warn(`[STT Gemini] ${currentModel} failed on attempt ${attempt}: ${err.message}`);
            break; // Break the attempt loop and try the next model
          }
        }
      }
    }


    
    // ULTIMATE FALLBACK TO GROQ WHISPER-LARGE-V3 IF ALL GEMINI MODELS FAIL/RATE LIMIT
    console.warn('[STT Gemini] All Gemini models failed or rate-limited. Falling back to Groq whisper-large-v3...');
    try {
      const Groq = require('groq-sdk');
      const env = require('../../config/env');
      const groqClient = new Groq({ apiKey: env.groqApiKey || process.env.GROQ_API_KEY });
      const fsModule = require('fs');
      
      const gRes = await groqClient.audio.transcriptions.create({
        file: fsModule.createReadStream(audioFilePath),
        model: 'whisper-large-v3',
        response_format: 'verbose_json',
      });

      const transcript = (gRes.text || '').trim();
      return {
        rawText: transcript,
        segments: [{
          speaker: 'Speaker',
          startTime: 0,
          endTime: Math.round(gRes.duration || 0),
          text: transcript,
        }],
        language: 'en',
        provider: 'groq-whisper-large-v3',
      };
    } catch (groqErr) {
      console.error('[STT Gemini] Groq ultimate fallback failed:', groqErr.message);
      throw lastErr; 
    }
  }
}

module.exports = GeminiSpeechToTextProvider;