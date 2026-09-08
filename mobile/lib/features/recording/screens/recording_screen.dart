import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';
import '../../meetings/models/meeting_model.dart';
import '../../meetings/controllers/meeting_controller.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/background_processing_service.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final Meeting meeting;

  const RecordingScreen({super.key, required this.meeting});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;
  String? _pickedFileName;

  // Processing Progress States
  bool _isProcessing = false;
  String _processingStage = '';
  double _processingPercentage = 0.0;
  int _elapsedProcessingSeconds = 0;
  int _estimatedTotalSeconds = 45; // dynamic estimation based on file
  Timer? _processingTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _processingTimer?.cancel();
    _pollingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startRecordTimer() {
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _recordDurationSeconds++;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath =
            '${dir.path}/recording_${widget.meeting.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 160000, // Crystal clear 160kbps bitrate
            sampleRate: 48000, // Studio-grade 48kHz sampling for distinct voice separation
            numChannels: 1, // Clean mono voice capture
            autoGain: true, // Hardware auto-gain control to balance loud & soft speakers
            echoCancel: true, // Acoustic echo cancellation
            noiseSuppress: true, // Background ambient noise suppression
          ),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDurationSeconds = 0;
          _recordedFilePath = filePath;
          _pickedFileName = null;
        });

        _startRecordTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
    } catch (e) {
      debugPrint('Pause error: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
    } catch (e) {
      debugPrint('Resume error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isPaused = false;
        if (path != null) _recordedFilePath = path;
      });

      _showCompletionDialog();
    } catch (e) {
      debugPrint('Stop error: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      // NOTE: We use FileType.any because Android/iOS system file pickers frequently
      // gray out / disable .m4a and .aac files when FileType.custom or FileType.audio is used,
      // due to Android OS MIME-type mismatch (audio/mp4 vs audio/x-m4a vs video/mp4).
      // FileType.any enables ALL files to be tapped and selectable, and we validate the extension below.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        // User dismissed the picker without choosing
        return;
      }

      final pickedFile = result.files.single;
      final path = pickedFile.path;
      final name = pickedFile.name;

      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access the selected file. Please select a local file on your device.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check extension if picked through FileType.any
      final ext = name.split('.').last.toLowerCase();
      final validExtensions = ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'mp4', 'opus', 'wma', 'amr'];
      if (!validExtensions.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('".$ext" is not a supported audio format. Please choose MP3, M4A, WAV, or AAC.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The selected file does not exist on disk.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate duration using AudioPlayer (Limit: 30 minutes = 1800 seconds)
      final tempPlayer = AudioPlayer();
      Duration? audioDuration;
      try {
        audioDuration = await tempPlayer.setFilePath(path);
      } catch (_) {}
      await tempPlayer.dispose();

      if (audioDuration != null && audioDuration.inSeconds > 1800) {
        final mins = (audioDuration.inSeconds / 60).toStringAsFixed(1);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Audio Too Long'),
                ],
              ),
              content: Text(
                'The selected audio is $mins minutes long.\n\nOnly audio files up to 30 minutes are supported.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK, Choose Another'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final fileSizeMB = file.lengthSync() / (1024 * 1024);
      if (fileSizeMB > 150) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File size (${fileSizeMB.toStringAsFixed(1)} MB) exceeds the 150 MB limit.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _recordedFilePath = path;
        _pickedFileName = name;
        if (audioDuration != null) {
          _recordDurationSeconds = audioDuration.inSeconds;
        }
      });

      if (mounted) {
        final durationLabel = audioDuration != null
            ? '${(audioDuration.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(audioDuration.inSeconds % 60).toString().padLeft(2, '0')}'
            : 'Detected';

        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Audio File Icon Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withAlpha(70),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.audio_file_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Audio File Selected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your recording file is verified and ready for Speech-to-Text & AI analysis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Selected File Name Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              size: 16, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metrics Row (Duration + File Size)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Duration Metric
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.timer_rounded,
                                  size: 16,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DURATION',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      durationLabel,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          height: 28,
                          width: 1,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 12),

                        // Size Metric
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.sd_storage_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SIZE',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${fileSizeMB.toStringAsFixed(2)} MB',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Primary Upload CTA
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _uploadAndProcessMeeting();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withAlpha(60),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Upload & Process MOM',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cancel Action
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _recordedFilePath = null;
                        _pickedFileName = null;
                      });
                    },
                    child: const Text(
                      'Choose Another File',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File selection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showCompletionDialog() {
    final fileSizeKB = _recordedFilePath != null && File(_recordedFilePath!).existsSync()
        ? (File(_recordedFilePath!).lengthSync() / 1024).toStringAsFixed(1)
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Success Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withAlpha(70),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Meeting Recorded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your session audio has been captured in studio quality and is ready for AI analysis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Metric Stats Row Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Duration Metric
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.timer_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DURATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDuration(_recordDurationSeconds),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 32,
                      width: 1,
                      color: const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 12),

                    // File / Quality Metric
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 18,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AUDIO SIZE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fileSizeKB != null ? '$fileSizeKB KB' : 'Studio AAC',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _uploadAndProcessMeeting();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withAlpha(60),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Upload & Generate MOM',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Re-record / Cancel text action
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _recordDurationSeconds = 0;
                    _recordedFilePath = null;
                  });
                },
                child: const Text(
                  'Discard & Re-record',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startProcessingProgressSimulation(int estimatedSeconds) {
    _elapsedProcessingSeconds = 0;
    _estimatedTotalSeconds = estimatedSeconds;
    _processingPercentage = 5.0;

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedProcessingSeconds++;

        // Smooth gradual progress bar animation towards 95% until server completes
        if (_processingPercentage < 92.0) {
          final target = (_elapsedProcessingSeconds / _estimatedTotalSeconds) * 90.0;
          if (target > _processingPercentage) {
            _processingPercentage = target;
          } else {
            _processingPercentage += 0.5;
          }
        }
      });
    });

    // Also poll backend every 3 seconds for exact status updates
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final client = ApiClient();
        final res = await client.dio.get(
          '${ApiConstants.meetings}/${widget.meeting.id}/processing-status',
        );
        if (res.data['success'] == true) {
          final stage = res.data['data']['currentStage'];
          final percent = (res.data['data']['progressPercent'] as num?)?.toDouble() ?? 0.0;
          if (mounted && percent > _processingPercentage) {
            setState(() {
              _processingPercentage = percent;
              if (stage == 'transcription') {
                _processingStage = 'Transcribing audio with Speech AI...';
              } else if (stage == 'ai_analysis' || stage == 'mom_generation') {
                _processingStage = 'Extracting Structured Minutes of Meeting...';
              }
            });
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _uploadAndProcessMeeting() async {
    int fileSizeMB = 5;
    if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
      fileSizeMB = (File(_recordedFilePath!).lengthSync() / (1024 * 1024)).ceil();
    }

    // Dynamic time estimation: ~15s base + 2s per MB (GPT-4o is slower than mini)
    final estimatedSeconds = (15 + (fileSizeMB * 2)).toInt().clamp(30, 300);

    setState(() {
      _isProcessing = true;
      _processingStage = 'Uploading audio file to backend...';
      _processingPercentage = 10.0;
    });

    _startProcessingProgressSimulation(estimatedSeconds);

    try {
      final client = ApiClient();

      // Step 1: Upload audio file
      if (_recordedFilePath != null && File(_recordedFilePath!).existsSync()) {
        final fileName = _pickedFileName ?? 'recording_${widget.meeting.id}.m4a';
        final formData = FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            _recordedFilePath!,
            filename: fileName,
          ),
        });

        await client.dio.post(
          '${ApiConstants.meetings}/${widget.meeting.id}/upload',
          data: formData,
        );
      }

      // Step 2: Update duration
      await ref.read(meetingRepositoryProvider).updateMeeting(
            id: widget.meeting.id,
            duration: _recordDurationSeconds,
          );

      // Step 3: Kick off async STT & AI processing (returns 202 immediately)
      setState(() {
        _processingStage = 'Starting Speech-to-Text transcription...';
        if (_processingPercentage < 35.0) _processingPercentage = 35.0;
      });

      // Register with app-wide background processing service so user gets notified if they leave
      BackgroundProcessingService().startTracking(
        meetingId: widget.meeting.id,
        meetingTitle: widget.meeting.title,
      );

      // POST /process returns 202 immediately — backend runs in background
      await client.dio.post(
        '${ApiConstants.meetings}/${widget.meeting.id}/process',
      );

      setState(() {
        _processingStage = 'AI is transcribing your audio accurately...';
        if (_processingPercentage < 40.0) _processingPercentage = 40.0;
      });

      // Step 4: Poll /processing-status until completed or failed
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        try {
          final res = await client.dio.get(
            '${ApiConstants.meetings}/${widget.meeting.id}/processing-status',
          );
          if (res.data['success'] == true) {
            final data = res.data['data'];
            final stage = data['currentStage'] as String? ?? '';
            final percent = (data['progressPercent'] as num?)?.toDouble() ?? 0.0;
            final meetingStatus = data['meetingStatus'] as String? ?? '';

            if (mounted && percent > _processingPercentage) {
              setState(() {
                _processingPercentage = percent;
                if (stage == 'transcription') {
                  _processingStage = 'Speech-to-Text: Transcribing Audio...';
                } else if (stage == 'ai_analysis') {
                  _processingStage = 'AI Engine: Extracting Structured Minutes...';
                } else if (stage == 'mom_generation') {
                  _processingStage = 'Finalising Minutes of Meeting...';
                }
              });
            }

            // ✅ Completed
            if (stage == 'completed' || meetingStatus == 'completed') {
              timer.cancel();
              _processingTimer?.cancel();
              BackgroundProcessingService().stopTracking(widget.meeting.id);

              if (mounted) {
                setState(() {
                  _processingPercentage = 100.0;
                  _processingStage = 'MOM Generated Successfully!';
                });

                await Future.delayed(const Duration(milliseconds: 800));

                if (!mounted) return;
                ref.read(meetingControllerProvider.notifier).fetchMeetings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF10B981),
                    content: Text('🎉 MOM generated from your recording!'),
                  ),
                );
                Navigator.of(context).pop();
              }
            }

            // ❌ Failed
            if (stage == 'failed' || meetingStatus == 'failed') {
              timer.cancel();
              _processingTimer?.cancel();
              BackgroundProcessingService().stopTracking(widget.meeting.id);
              if (mounted) {
                setState(() => _isProcessing = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade700,
                    content: Text('Processing failed: ${data['error'] ?? 'Unknown error'}'),
                  ),
                );
              }
            }
          }
        } catch (_) {
          // Ignore polling errors (tunnel may be momentarily unreachable)
        }
      });
    } catch (e) {
      _processingTimer?.cancel();
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final remainingSeconds =
        (_estimatedTotalSeconds - _elapsedProcessingSeconds).clamp(0, 300);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.meeting.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Session Recording Studio',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isProcessing
            ? _buildProcessingState(remainingSeconds)
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Meeting Context Card (Agenda + Attendees)
                    _buildMeetingContextCard(),
                    const SizedBox(height: 20),

                    // Main Recording / Audio Center Studio Card
                    _buildStudioCard(),
                    const SizedBox(height: 20),

                    // Action Controls
                    if (!_isRecording) ...[
                      _buildActionOptions(),
                    ] else ...[
                      _buildActiveRecordingControls(),
                    ],
                    const SizedBox(height: 24),

                    // Footer branding
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Studio Quality Audio • Powered by Anaxistech AI',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMeetingContextCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withAlpha(8),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEDF2F7)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    size: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Meeting Overview',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    '${widget.meeting.participants.length} ${widget.meeting.participants.length == 1 ? 'Attendee' : 'Attendees'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agenda Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Agenda',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.meeting.agenda.isNotEmpty
                                ? widget.meeting.agenda
                                : 'General Discussion & Strategy Review',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // Attendees Section
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.group_rounded, size: 14, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Participants',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (widget.meeting.participants.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: widget.meeting.participants.map((name) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 9,
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const Text(
                              'No attendees registered for this session',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isRecording
              ? (_isPaused ? const Color(0xFFFBBF24) : const Color(0xFFFCA5A5))
              : const Color(0xFFE2E8F0),
          width: _isRecording ? 1.8 : 1.2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _isRecording
              ? [
                  _isPaused ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
                  Colors.white,
                ]
              : [
                  const Color(0xFFF8FAFC),
                  Colors.white,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: _isRecording
                ? (_isPaused
                    ? const Color(0xFFF59E0B).withAlpha(20)
                    : const Color(0xFFEF4444).withAlpha(20))
                : const Color(0xFF1E293B).withAlpha(8),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated Pulse / Mic Ring
          Stack(
            alignment: Alignment.center,
            children: [
              if (_isRecording && !_isPaused)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF4444).withAlpha(25),
                  ),
                ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isRecording
                        ? (_isPaused
                            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                            : [const Color(0xFFEF4444), const Color(0xFFDC2626)])
                        : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isRecording
                          ? (_isPaused
                              ? const Color(0xFFF59E0B).withAlpha(70)
                              : const Color(0xFFEF4444).withAlpha(80))
                          : const Color(0xFF1E3A8A).withAlpha(50),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording
                      ? (_isPaused ? Icons.pause_rounded : Icons.mic_rounded)
                      : (_pickedFileName != null ? Icons.audio_file_rounded : Icons.mic_rounded),
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Status Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _isRecording
                  ? (_isPaused ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2))
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isRecording
                    ? (_isPaused ? const Color(0xFFFDE68A) : const Color(0xFFFECACA))
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRecording)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _isPaused ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  _isRecording
                      ? (_isPaused ? 'RECORDING PAUSED' : 'LIVE RECORDING IN PROGRESS')
                      : (_pickedFileName != null
                          ? 'AUDIO FILE SELECTED'
                          : 'READY TO RECORD OR UPLOAD'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: _isRecording
                        ? (_isPaused ? const Color(0xFFB45309) : const Color(0xFFB91C1C))
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // High Contrast Digital Timer
          Text(
            _formatDuration(_recordDurationSeconds),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: 3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          if (_pickedFileName != null && !_isRecording) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _pickedFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionOptions() {
    return Column(
      children: [
        // Primary Record Button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _startRecording,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withAlpha(70),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Start Recording Microphone',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Modern OR Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR CHOOSE AUDIO FILE',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 14),

        // Secondary Upload Button
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _pickAudioFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_rounded, color: Color(0xFF1E3A8A), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Upload Audio File (.mp3, .m4a, .wav)',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveRecordingControls() {
    return Row(
      children: [
        // Pause / Resume Button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isPaused ? _resumeRecording : _pauseRecording,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF334155).withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPaused ? 'Resume' : 'Pause',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Stop & Finish Button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _stopRecording,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'End & Process',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingState(int remainingSeconds) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Progress Radial Card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Colors.white],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withAlpha(12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Live AI Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4F46E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'AI PROCESSING ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Large Radial Progress with Glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E3A8A).withAlpha(10),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: (_processingPercentage / 100).clamp(0.0, 1.0),
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_processingPercentage.toInt()}%',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -1,
                            ),
                          ),
                          const Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Current Stage Dynamic Headline
                  Text(
                    _processingStage.isNotEmpty
                        ? _processingStage
                        : 'Processing session audio...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Estimated Remaining Time Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF475569)),
                        const SizedBox(width: 6),
                        Text(
                          remainingSeconds > 0
                              ? 'Estimated: ~$remainingSeconds sec remaining'
                              : 'Wrapping up final details...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Run in Background Button inside card
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E3A8A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: const Row(
                              children: [
                                Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Running in background. You will receive a notification when your MOM is ready!',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E293B).withAlpha(6),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1E3A8A)),
                            SizedBox(width: 8),
                            Text(
                              'Run in Background',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Footer
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Powered by Anaxistech AI',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
