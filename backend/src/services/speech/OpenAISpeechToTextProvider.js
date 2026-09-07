const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const OpenAI = require('openai');
const SpeechToTextProvider = require('./SpeechToTextProvider');
const env = require('../../config/env');

const CHUNK_DURATION_SECONDS = 900; // 15-minute chunks (Whisper supports up to 25 MB)
const MAX_WHISPER_FILE_MB = 24;

class OpenAISpeechToTextProvider extends SpeechToTextProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.stt,
      timeout: 10 * 60 * 1000,
    });
  }

  /**
   * Splits large audio files into chunks using FFmpeg stream copy (no re-encoding = lossless)
   */
  prepareAudioFiles(audioFilePath) {
    let duration = 0;
    try {
      const out = execSync(
        `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${audioFilePath}"`,
        { stdio: ['pipe', 'pipe', 'ignore'] }
      )
        .toString()
        .trim();
      duration = parseFloat(out) || 0;
    } catch (_) {}

    const stats = fs.statSync(audioFilePath);
    const sizeMB = stats.size / (1024 * 1024);

    // If audio is short enough and small enough, process as-is (no re-encoding)
    if (duration > 0 && duration <= CHUNK_DURATION_SECONDS && sizeMB < MAX_WHISPER_FILE_MB) {
      return [audioFilePath];
    }

    const dir = path.dirname(audioFilePath);
    const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
    const ext = path.extname(audioFilePath); // Keep same extension as input (mp3/m4a/wav)
    const chunkPattern = path.join(dir, `${baseName}_chunk_%03d${ext}`);

    console.log(
      `[STT] Audio: ${(duration / 60).toFixed(1)} min (${sizeMB.toFixed(1)} MB) - chunking into 5-min pieces...`
    );

    try {
      // Remove old chunk files first
      const existing = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_chunk_`));
      for (const f of existing) fs.unlinkSync(path.join(dir, f));

      execSync(
        `ffmpeg -y -i "${audioFilePath}" -f segment -segment_time ${CHUNK_DURATION_SECONDS} -c copy "${chunkPattern}"`,
        { stdio: 'pipe' }
      );

      const chunks = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_chunk_`))
        .sort()
        .map((f) => path.join(dir, f));

      return chunks.length > 0 ? chunks : [audioFilePath];
    } catch (err) {
      console.error('[STT] Chunking failed, using original:', err.message);
      return [audioFilePath];
    }
  }

  /**
   * Removes Whisper hallucination loops — repeating sentences/phrases that appear 3+ times
   * This is a common Whisper failure mode on low-quality or trailing audio
   */
  deduplicateTranscript(text) {
    if (!text || text.length < 50) return text;

    // Split into sentences
    const sentences = text.split(/(?<=[.?!])\s+/);
    const seen = new Map();
    const result = [];

    for (const sentence of sentences) {
      const normalized = sentence.trim().toLowerCase().replace(/\s+/g, ' ');
      if (!normalized || normalized.length < 5) continue;

      const count = seen.get(normalized) || 0;
      // Allow up to 2 occurrences (genuine repetition), but drop beyond that
      if (count < 2) {
        result.push(sentence.trim());
        seen.set(normalized, count + 1);
      }
    }

    return result.join(' ');
  }

  /**
   * Main transcription method: uses OpenAI Whisper-1 audio translation for
   * multilingual Indian business meetings (Gujarati, Hindi, English, code-switching)
   */
  async transcribe(audioFilePath, options = {}) {
    if (!fs.existsSync(audioFilePath)) {
      throw new Error(`Audio file not found: ${audioFilePath}`);
    }

    const filesToProcess = this.prepareAudioFiles(audioFilePath);

    let combinedRawText = '';
    const combinedSegments = [];
    let timeOffsetSeconds = 0;

    const participantsList =
      Array.isArray(options.participants) && options.participants.length > 0
        ? options.participants.join(', ')
        : 'Priyanka, Harmish, Vijay, Jay';

    // IMPORTANT: Whisper prompt must NOT end with a complete sentence.
    // If it ends with a complete sentence (e.g., "Spoken in a mix of English, Gujarati, and Hindi.")
    // Whisper will hallucinate by echoing that sentence back when audio is unclear.
    // Always end the prompt mid-phrase or with a comma-terminated list of keywords.
    // Enhanced prompt keywords for business meetings with Indian accents / regional speech
    const whisperPrompt = `Indian business meeting in English, Gujarati, and Hindi. Participants: ${participantsList}. Topics: business expansion, client meetings, scheduling, travel logistics, flights, dates 19th 20th 21st 22nd 23rd 24th 25th September, expo, target audience companies with 11+ headcount, transport, metro vs cabs, VoIP communication, Vyke, Teams, WhatsApp,`;

    // 1. Try Groq Whisper-Large-V3 first if Groq API Key is available
    // Groq whisper-large-v3 translations converts Gujarati/Hindi speech directly to rich English transcript
    if (env.groqApiKey) {
      try {
        console.log(`[STT] Running primary STT via Groq whisper-large-v3 translations for maximum multilingual fidelity...`);
        const Groq = require('groq-sdk');
        const groqClient = new Groq({ apiKey: env.groqApiKey });

        let groqRawText = '';
        let groqOffset = 0;
        for (let i = 0; i < filesToProcess.length; i++) {
          const filePath = filesToProcess[i];
          let gRes;
          try {
            // First attempt: translations.create to directly produce full English transcript
            gRes = await groqClient.audio.translations.create({
              file: fs.createReadStream(filePath),
              model: 'whisper-large-v3',
              response_format: 'verbose_json',
              temperature: 0,
              prompt: whisperPrompt,
            });
          } catch (tErr) {
            // Fallback: transcriptions.create
            gRes = await groqClient.audio.transcriptions.create({
              file: fs.createReadStream(filePath),
              model: 'whisper-large-v3',
              response_format: 'verbose_json',
              temperature: 0,
              prompt: whisperPrompt,
            });
          }

          if (gRes && gRes.text) {
            groqRawText += (groqRawText ? ' ' : '') + gRes.text.trim();
          }
          if (gRes && Array.isArray(gRes.segments)) {
            gRes.segments.forEach((seg, idx) => {
              combinedSegments.push({
                speaker: `Speaker ${(idx % 2) + 1}`,
                startTime: Math.round(groqOffset + (seg.start || 0)),
                endTime: Math.round(groqOffset + (seg.end || 0)),
                text: (seg.text || '').trim(),
              });
            });
          }
          groqOffset += (gRes?.duration || 0);
        }

        if (groqRawText.trim().length > 100) {
          console.log(`[STT] Groq whisper-large-v3 captured ${groqRawText.length} chars of high-fidelity transcript!`);
          return {
            rawText: this.deduplicateTranscript(groqRawText),
            segments: combinedSegments.length > 0 ? combinedSegments : [{
              speaker: 'Speaker 1',
              startTime: 0,
              endTime: Math.round(groqOffset),
              text: groqRawText.trim(),
            }],
            provider: 'groq-whisper-large-v3',
          };
        }
      } catch (groqErr) {
        console.warn(`[STT] Groq whisper-large-v3 failed (${groqErr.message}), falling back to OpenAI Whisper...`);
      }
    }

    // 2. OpenAI Whisper-1 Fallback
    for (let i = 0; i < filesToProcess.length; i++) {
      const filePath = filesToProcess[i];
      const stats = fs.statSync(filePath);
      console.log(
        `[STT OpenAI] Part ${i + 1}/${filesToProcess.length}: ${path.basename(filePath)} (${(stats.size / 1024 / 1024).toFixed(2)} MB)`
      );

      let response;
      try {
        // PRIMARY: Use transcriptions.create without language lock for best multilingual accuracy
        const fileStream = fs.createReadStream(filePath);
        response = await this.openai.audio.transcriptions.create({
          file: fileStream,
          model: 'whisper-1',
          response_format: 'verbose_json',
          prompt: whisperPrompt.substring(0, 800),
        });
        console.log(`[STT OpenAI] Transcription successful (auto-detect language)`);
      } catch (transcribeErr) {
        console.warn(`[STT OpenAI] Transcription failed (${transcribeErr.message}), trying translation fallback...`);
        const fileStream2 = fs.createReadStream(filePath);
        response = await this.openai.audio.translations.create({
          file: fileStream2,
          model: 'whisper-1',
          response_format: 'verbose_json',
          prompt: whisperPrompt.substring(0, 800),
        });
        console.log(`[STT OpenAI] Translation fallback successful`);
      }

      let chunkText = (response.text || '').trim();

      // De-duplicate Whisper hallucination loops before adding to combined transcript
      chunkText = this.deduplicateTranscript(chunkText);

      if (chunkText) {
        combinedRawText += (combinedRawText ? ' ' : '') + chunkText;
      }

      const chunkDuration = response.duration || 0;

      // Build time-stamped segments for display in the transcript view
      if (Array.isArray(response.segments)) {
        response.segments.forEach((seg) => {
          const segText = (seg.text || '').trim();
          if (segText) {
            combinedSegments.push({
              speaker: 'Speaker',
              startTime: Math.round(timeOffsetSeconds + (seg.start || 0)),
              endTime: Math.round(timeOffsetSeconds + (seg.end || 0)),
              text: segText,
            });
          }
        });
      }

      timeOffsetSeconds += chunkDuration;

      // Cleanup temporary chunk files (not original)
      if (filePath !== audioFilePath && fs.existsSync(filePath)) {
        try { fs.unlinkSync(filePath); } catch (_) {}
      }
    }

    // Fallback: if no segments were built, wrap the full text as one segment
    if (combinedSegments.length === 0 && combinedRawText.trim().length > 0) {
      combinedSegments.push({
        speaker: 'Speaker',
        startTime: 0,
        endTime: Math.round(timeOffsetSeconds),
        text: combinedRawText.trim(),
      });
    }

    console.log(`[STT] Final transcript: ${combinedRawText.length} chars, ${combinedSegments.length} segments`);

    return {
      rawText: combinedRawText,
      segments: combinedSegments,
      language: 'en',
    };
  }
}

module.exports = OpenAISpeechToTextProvider;
