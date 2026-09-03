import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../../../core/theme/app_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.title,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      await _player.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load audio stream';
        });
      }
      debugPrint('Error loading audio from ${widget.audioUrl}: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours > 0 ? '${d.inHours}:' : '';
    return '$hours$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.audiotrack, color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Meeting Audio Recording',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? _player.duration;
                        if (duration != null && duration.inSeconds > 0) {
                          return Text(
                            'Total Duration: ${_formatDuration(duration)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return const Text(
                          'Ready to play',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _initAudio,
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else ...[
            // Progress Bar with exact elapsed and total timing
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.duration ?? Duration.zero;

                return ProgressBar(
                  progress: position,
                  total: duration,
                  buffered: _player.bufferedPosition,
                  progressBarColor: AppTheme.primaryColor,
                  baseBarColor: const Color(0xFFE2E8F0),
                  bufferedBarColor: const Color(0xFFCBD5E1),
                  thumbColor: AppTheme.primaryColor,
                  thumbRadius: 7.0,
                  timeLabelLocation: TimeLabelLocation.sides,
                  timeLabelTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  onSeek: (duration) {
                    _player.seek(duration);
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            // Play/Pause and Seek Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replay 10 seconds
                IconButton(
                  onPressed: () {
                    final newPos = _player.position - const Duration(seconds: 10);
                    _player.seek(newPos < Duration.zero ? Duration.zero : newPos);
                  },
                  icon: const Icon(Icons.replay_10),
                  iconSize: 24,
                  color: AppTheme.textSecondary,
                  tooltip: 'Rewind 10s',
                ),
                const SizedBox(width: 12),

                // Play / Pause Button
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;

                    if (_isLoading ||
                        processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      );
                    } else if (playing != true) {
                      return IconButton.filled(
                        onPressed: _player.play,
                        iconSize: 28,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.play_arrow),
                      );
                    } else {
                      return IconButton.filled(
                        onPressed: _player.pause,
                        iconSize: 28,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.pause),
                      );
                    }
                  },
                ),
                const SizedBox(width: 12),

                // Forward 10 seconds
                IconButton(
                  onPressed: () {
                    final total = _player.duration ?? Duration.zero;
                    final newPos = _player.position + const Duration(seconds: 10);
                    _player.seek(newPos > total ? total : newPos);
                  },
                  icon: const Icon(Icons.forward_10),
                  iconSize: 24,
                  color: AppTheme.textSecondary,
                  tooltip: 'Forward 10s',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
