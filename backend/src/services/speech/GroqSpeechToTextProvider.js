const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const Groq = require('groq-sdk');
const SpeechToTextProvider = require('./SpeechToTextProvider');
const env = require('../../config/env');

const CHUNK_DURATION_SECONDS = 300; // 5-minute chunks for ultra-fast, robust Groq Whisper processing

class GroqSpeechToTextProvider extends SpeechToTextProvider {
  constructor() {
    super();
    this.groq = new Groq({
      apiKey: env.groqApiKey,
    });
  }

  /**
   * Compresses audio to speech-optimized 32kbps mono mp3 and splits into 5-minute chunks
   * if duration > 5 minutes or size > 20 MB.
   * @param {string} audioFilePath
   * @returns {Array<string>} Array of chunk file paths
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

    if (duration > 0 && duration <= CHUNK_DURATION_SECONDS && sizeMB < 20) {
      return [audioFilePath];
    }

    console.log(
      `[Groq Whisper STT] Audio length: ${(duration / 60).toFixed(1)} mins (${sizeMB.toFixed(1)} MB). Chunking into 5-minute pieces for rapid Groq processing...`
    );

    const dir = path.dirname(audioFilePath);
    const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
    const chunkPattern = path.join(dir, `${baseName}_groq_part_%03d.mp3`);

    try {
      // Clean previous temporary chunks if any
      const existing = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_groq_part_`) && f.endsWith('.mp3'));
      for (const f of existing) {
        fs.unlinkSync(path.join(dir, f));
      }

      // Convert and segment directly in 1 command: 32kbps mono, 16kHz, 5-minute chunks
      execSync(
        `ffmpeg -y -i "${audioFilePath}" -vn -ar 16000 -ac 1 -b:a 32k -f segment -segment_time ${CHUNK_DURATION_SECONDS} "${chunkPattern}"`,
        { stdio: 'pipe' }
      );

      const chunkFiles = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_groq_part_`) && f.endsWith('.mp3'))
        .sort()
        .map((f) => path.join(dir, f));

      console.log(`[Groq Whisper STT] Generated ${chunkFiles.length} chunk(s) to process.`);
      return chunkFiles.length > 0 ? chunkFiles : [audioFilePath];
    } catch (err) {
      console.error('[Groq Whisper STT] Chunking failed, falling back to original:', err.message);
      return [audioFilePath];
    }
  }

  /**
   * Transcribes an audio file using Groq whisper-large-v3 using the exact user-specified format:
   * {
   *   "model": "whisper-large-v3",
   *   "temperature": 0,
   *   "response_format": "verbose_json",
   *   "file": ...
   * }
   * @param {string} audioFilePath
   * @param {Object} options
   */
  async transcribe(audioFilePath, options = {}) {
    if (!fs.existsSync(audioFilePath)) {
      throw new Error(`Audio file does not exist at path: ${audioFilePath}`);
    }

    const filesToTranscribe = this.prepareAudioFiles(audioFilePath);

    let combinedRawText = '';
    const combinedSegments = [];
    let timeOffsetSeconds = 0;
    let detectedLanguage = 'en';

    for (let i = 0; i < filesToTranscribe.length; i++) {
      const filePath = filesToTranscribe[i];
      const stats = fs.statSync(filePath);
      console.log(
        `[Groq Whisper STT] Transcribing chunk ${i + 1}/${filesToTranscribe.length}: ${path.basename(filePath)} (${(stats.size / 1024 / 1024).toFixed(2)} MB)`
      );

      const fileStream = fs.createReadStream(filePath);
      const response = await this.groq.audio.transcriptions.create({
        file: fileStream,
        model: 'whisper-large-v3',
        temperature: 0,
        response_format: 'verbose_json',
        language: options.language,
      });

      if (response.language) detectedLanguage = response.language;

      if (response.text) {
        combinedRawText += (combinedRawText ? ' ' : '') + response.text.trim();
      }

      const fileDuration = response.duration || 0;

      if (Array.isArray(response.segments)) {
        response.segments.forEach((seg, idx) => {
          combinedSegments.push({
            speaker: `Speaker ${(idx % 2) + 1}`,
            startTime: Math.round(timeOffsetSeconds + (seg.start || 0)),
            endTime: Math.round(timeOffsetSeconds + (seg.end || 0)),
            text: (seg.text || '').trim(),
          });
        });
      }

      timeOffsetSeconds += fileDuration;

      // Clean up chunk file if it's not the original uploaded file
      if (filePath !== audioFilePath && fs.existsSync(filePath)) {
        try {
          fs.unlinkSync(filePath);
        } catch (_) {}
      }
    }

    if (combinedSegments.length === 0 && combinedRawText.trim().length > 0) {
      combinedSegments.push({
        speaker: 'Speaker 1',
        startTime: 0,
        endTime: Math.round(timeOffsetSeconds),
        text: combinedRawText.trim(),
      });
    }

    return {
      rawText: combinedRawText,
      segments: combinedSegments,
      language: detectedLanguage,
    };
  }
}

module.exports = GroqSpeechToTextProvider;
