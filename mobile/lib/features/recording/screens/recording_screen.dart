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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'mp4'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final file = File(path);
        // Validate duration using AudioPlayer (Strict 30-minute limit = 1800 seconds)
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
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Audio Too Long'),
                  ],
                ),
                content: Text(
                  'The selected audio is $mins minutes long.\n\nOnly audio files up to 30 minutes are allowed.',
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

        setState(() {
          _recordedFilePath = path;
          _pickedFileName = name;
        });

        if (mounted) {
          final durationLabel = audioDuration != null
              ? '${(audioDuration.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(audioDuration.inSeconds % 60).toString().padLeft(2, '0')}'
              : 'Under 30 mins';

          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Audio File Selected'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.audio_file, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Duration: $durationLabel (Max: 30:00)'),
                  const SizedBox(height: 4),
                  Text('Size: ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  const SizedBox(height: 12),
                  const Text('Ready to upload and process with OpenAI.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _uploadAndProcessMeeting();
                  },
                  child: const Text('Upload & Process with OpenAI'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e')),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Meeting Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${_formatDuration(_recordDurationSeconds)}'),
            const SizedBox(height: 8),
            Text(
              _recordedFilePath != null && File(_recordedFilePath!).existsSync()
                  ? 'Real Audio: Recorded (${(File(_recordedFilePath!).lengthSync() / 1024).toStringAsFixed(1)} KB)'
                  : 'Audio: Ready for AI processing',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _uploadAndProcessMeeting();
            },
            child: const Text('Upload & Process with OpenAI'),
          ),
        ],
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
                _processingStage = 'Transcribing with OpenAI Whisper...';
              } else if (stage == 'ai_analysis' || stage == 'mom_generation') {
                _processingStage = 'Extracting Structured MOM with GPT-4o-mini...';
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

    // Dynamic time estimation: ~10 seconds base + ~1.5 seconds per MB
    final estimatedSeconds = (15 + (fileSizeMB * 1.5)).toInt().clamp(20, 120);

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

      // Step 3: Trigger STT & OpenAI MOM processing
      setState(() {
        _processingStage = 'OpenAI Whisper (Transcribing Audio)...';
        if (_processingPercentage < 35.0) _processingPercentage = 35.0;
      });

      final response = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meeting.id}/process',
      );

      _processingTimer?.cancel();
      _pollingTimer?.cancel();

      if (response.data['success'] == true) {
        setState(() {
          _processingPercentage = 100.0;
          _processingStage = 'Completed!';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        ref.read(meetingControllerProvider.notifier).fetchMeetings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.accentColor,
              content: Text('🎉 OpenAI Generated MOM from your Audio!'),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception(response.data['error'] ?? 'Processing failed');
      }
    } catch (e) {
      _processingTimer?.cancel();
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Processing error: ${e.toString().replaceAll('Exception: ', '')}'),
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
      appBar: AppBar(
        title: Text(widget.meeting.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isProcessing
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Large Percentage Display
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: (_processingPercentage / 100).clamp(0.0, 1.0),
                                strokeWidth: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_processingPercentage.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Current Stage Text
                        Text(
                          _processingStage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Approximate Remaining Time Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                remainingSeconds > 0
                                    ? 'Approx. ~$remainingSeconds sec remaining'
                                    : 'Finishing up...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Powered by OpenAI Whisper + GPT-4o-mini',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Meeting Context Card: Agenda & 5+ Attendees Display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.assignment_outlined,
                                      size: 18, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Meeting Agenda',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.meeting.agenda.isNotEmpty
                                  ? widget.meeting.agenda
                                  : 'General Discussion & Review',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.people_outline,
                                      size: 18, color: Colors.green),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Attendees (${widget.meeting.participants.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (widget.meeting.participants.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: widget.meeting.participants.map((name) {
                                  return Chip(
                                    avatar: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    label: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              )
                            else
                              const Text(
                                'No attendees registered yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Recording visualizer circle
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? (_isPaused ? Colors.orange.withAlpha(30) : Colors.red.withAlpha(30))
                              : AppTheme.primaryColor.withAlpha(20),
                        ),
                        child: Icon(
                          _isRecording ? Icons.mic : Icons.mic_none,
                          size: 56,
                          color: _isRecording
                              ? (_isPaused ? Colors.orange : Colors.red)
                              : AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status Text
                      Text(
                        _isRecording
                            ? (_isPaused ? '⏸ Paused' : '🔴 Recording Live Meeting...')
                            : (_pickedFileName != null
                                ? '📁 Selected: $_pickedFileName'
                                : 'Ready to Record or Upload'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isRecording ? Colors.red : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Timer Duration Display
                      Text(
                        _formatDuration(_recordDurationSeconds),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 24),

                    // Controls
                    if (!_isRecording) ...[
                      // Option 1: Live Record
                      ElevatedButton.icon(
                        onPressed: _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        icon: const Icon(Icons.fiber_manual_record),
                        label: const Text('Start Recording Microphone'),
                      ),
                      const SizedBox(height: 16),

                      // Divider / OR
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Option 2: Direct File Upload
                      OutlinedButton.icon(
                        onPressed: _pickAudioFile,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                        icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                        label: const Text(
                          'Upload Audio File (.mp3, .m4a, .wav)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800,
                              minimumSize: const Size(130, 48),
                            ),
                            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                            label: Text(_isPaused ? 'Resume' : 'Pause'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _stopRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              minimumSize: const Size(130, 48),
                            ),
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
