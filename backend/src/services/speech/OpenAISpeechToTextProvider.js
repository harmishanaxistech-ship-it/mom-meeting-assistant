const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const OpenAI = require('openai');
const SpeechToTextProvider = require('./SpeechToTextProvider');
const env = require('../../config/env');

const CHUNK_DURATION_SECONDS = 300; // 5-minute chunks

class OpenAISpeechToTextProvider extends SpeechToTextProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.stt,
      timeout: 10 * 60 * 1000,
    });
  }

  /**
   * Preprocesses audio losslessly or splits into chunks if duration > 5 minutes
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

    // If audio is under 5 mins and under 24MB, process file directly (lossless)
    if (duration > 0 && duration <= CHUNK_DURATION_SECONDS && sizeMB < 24) {
      return [audioFilePath];
    }

    const dir = path.dirname(audioFilePath);
    const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
    const chunkPattern = path.join(dir, `${baseName}_part_%03d.m4a`);

    console.log(
      `[Whisper STT] Audio length: ${(duration / 60).toFixed(1)} mins (${sizeMB.toFixed(1)} MB). Chunking into 5-minute pieces...`
    );

    try {
      const existing = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_part_`) && f.endsWith('.m4a'));
      for (const f of existing) {
        fs.unlinkSync(path.join(dir, f));
      }

      execSync(
        `ffmpeg -y -i "${audioFilePath}" -f segment -segment_time ${CHUNK_DURATION_SECONDS} -c copy "${chunkPattern}"`,
        { stdio: 'pipe' }
      );

      const chunkFiles = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_part_`) && f.endsWith('.m4a'))
        .sort()
        .map((f) => path.join(dir, f));

      return chunkFiles.length > 0 ? chunkFiles : [audioFilePath];
    } catch (err) {
      console.error('[Whisper STT] Chunking failed, using original file:', err.message);
      return [audioFilePath];
    }
  }

  /**
   * Transcribes/Translates audio with Whisper-1 using multilingual translation for flawless Gujarati, Hindi, and English processing
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

    const participantsList = Array.isArray(options.participants) && options.participants.length > 0
      ? options.participants.join(', ')
      : '';
    const titleText = options.title || 'Team Meeting';
    const agendaText = options.agenda || '';

    let whisperPrompt = `Indian business meeting discussion with participants: ${participantsList || 'Priyanka, Harmish, Vijay, Jay, Amit'}. Topics include software projects (Invest, B-Line, LJE Sports, Huddle sports app, Pickleball, Seward, Lehar), testing before holidays, Monday feedback compilation, deployment updates, and team resource planning.`;

    for (let i = 0; i < filesToTranscribe.length; i++) {
      const filePath = filesToTranscribe[i];
      const stats = fs.statSync(filePath);
      console.log(
        `[Whisper STT] Processing part ${i + 1}/${filesToTranscribe.length}: ${path.basename(filePath)} (${(stats.size / 1024 / 1024).toFixed(2)} MB)`
      );

      // Using OpenAI audio translations to convert Gujarati/Hindi/English mixed speech into crystal-clear English text
      const fileStream = fs.createReadStream(filePath);
      const response = await this.openai.audio.translations.create({
        file: fileStream,
        model: 'whisper-1',
        response_format: 'verbose_json',
        prompt: whisperPrompt.substring(0, 800),
      });

      if (response.text) {
        combinedRawText += (combinedRawText ? ' ' : '') + response.text.trim();
      }

      const fileDuration = response.duration || 0;

      if (Array.isArray(response.segments)) {
        response.segments.forEach((seg, idx) => {
          combinedSegments.push({
            speaker: `Speaker ${(idx % (options.participants?.length || 2)) + 1}`,
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
      language: 'en',
    };
  }
}

module.exports = OpenAISpeechToTextProvider;
