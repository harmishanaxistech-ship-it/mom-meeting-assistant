const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const OpenAI = require('openai');
const SpeechToTextProvider = require('./SpeechToTextProvider');
const env = require('../../config/env');

const CHUNK_DURATION_SECONDS = 300; // 5-minute chunks for rapid Whisper processing

class OpenAISpeechToTextProvider extends SpeechToTextProvider {
  constructor() {
    super();
    this.openai = new OpenAI({
      apiKey: env.openaiApiKey || env.apiKeys.stt,
      timeout: 10 * 60 * 1000,
    });
  }

  /**
   * Preprocesses audio with speech enhancement:
   * - Highpass filter (80Hz) to remove table thumps & mic handling rumble
   * - Lowpass filter (8000Hz) for crisp vocal range
   * - Dynamic audio normalization (loudnorm) so soft speakers and loud speakers have equal volume
   * - 16kHz mono 48kbps optimal Whisper format
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

    const dir = path.dirname(audioFilePath);
    const baseName = path.basename(audioFilePath, path.extname(audioFilePath));
    const cleanAudioPath = path.join(dir, `${baseName}_enhanced.mp3`);

    console.log(
      `[Whisper STT] Preprocessing audio for speech clarity & voice normalization...`
    );

    try {
      // Apply speech enhancement: highpass 80Hz + lowpass 8000Hz + loudnorm volume balancing
      execSync(
        `ffmpeg -y -i "${audioFilePath}" -af "highpass=f=80,lowpass=f=8000,loudnorm=I=-16:TP=-1.5:LRA=11" -vn -ar 16000 -ac 1 -b:a 48k "${cleanAudioPath}"`,
        { stdio: 'pipe' }
      );

      const enhancedStats = fs.statSync(cleanAudioPath);
      const enhancedSizeMB = enhancedStats.size / (1024 * 1024);

      if (duration > 0 && duration <= CHUNK_DURATION_SECONDS && enhancedSizeMB < 20) {
        return [cleanAudioPath];
      }

      // If longer than 5 minutes, segment enhanced audio
      console.log(`[Whisper STT] Chunking enhanced audio into 5-minute segments...`);
      const chunkPattern = path.join(dir, `${baseName}_enhanced_part_%03d.mp3`);

      const existing = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_enhanced_part_`) && f.endsWith('.mp3'));
      for (const f of existing) {
        fs.unlinkSync(path.join(dir, f));
      }

      execSync(
        `ffmpeg -y -i "${cleanAudioPath}" -f segment -segment_time ${CHUNK_DURATION_SECONDS} -c copy "${chunkPattern}"`,
        { stdio: 'pipe' }
      );

      const chunkFiles = fs
        .readdirSync(dir)
        .filter((f) => f.startsWith(`${baseName}_enhanced_part_`) && f.endsWith('.mp3'))
        .sort()
        .map((f) => path.join(dir, f));

      return chunkFiles.length > 0 ? chunkFiles : [cleanAudioPath];
    } catch (err) {
      console.error('[Whisper STT] Preprocessing failed, using fallback:', err.message);
      return [audioFilePath];
    }
  }

  /**
   * Transcribes audio with Whisper-1 using voice-guided prompts and multilingual conditioning
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

    const participantsList = Array.isArray(options.participants) && options.participants.length > 0
      ? options.participants.join(', ')
      : '';
    const titleText = options.title || 'Team Meeting';
    const agendaText = options.agenda || '';

    let whisperPrompt = `Indian business meeting titled "${titleText}". Language: English, Hindi, and Gujarati code-switching.`;
    if (participantsList) {
      whisperPrompt += ` Distinct speakers / Attendees: ${participantsList}.`;
    }
    if (agendaText) {
      whisperPrompt += ` Agenda topics: ${agendaText}.`;
    }
    whisperPrompt += ` Accurately transcribe all speaker turns, Gujarati words (નિર્ણય, ચર્ચા, પ્રશ્ન), Hindi words (फैसला, बातचीत, कार्य), and English business terms.`;

    for (let i = 0; i < filesToTranscribe.length; i++) {
      const filePath = filesToTranscribe[i];
      const stats = fs.statSync(filePath);
      console.log(
        `[Whisper STT] Transcribing part ${i + 1}/${filesToTranscribe.length}: ${path.basename(filePath)} (${(stats.size / 1024 / 1024).toFixed(2)} MB)`
      );

      const fileStream = fs.createReadStream(filePath);
      const response = await this.openai.audio.transcriptions.create({
        file: fileStream,
        model: 'whisper-1',
        response_format: 'verbose_json',
        timestamp_granularities: ['segment'],
        prompt: whisperPrompt.substring(0, 800),
      });

      if (response.language) detectedLanguage = response.language;

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
      language: detectedLanguage,
    };
  }
}

module.exports = OpenAISpeechToTextProvider;
