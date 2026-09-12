import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../../../core/theme/app_theme.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String title;
  final bool isDarkTheme;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.title,
    this.isDarkTheme = false,
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
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final uri = widget.audioUrl.trim();
      if (uri.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No audio source available';
          });
        }
        return;
      }

      if (uri.startsWith('http://') || uri.startsWith('https://')) {
        await _player.setUrl(uri);
      } else if (File(uri).existsSync()) {
        await _player.setFilePath(uri);
      } else {
        await _player.setUrl(uri);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Audio removed from server to optimize space';
        });
      }
      debugPrint('Note: Audio stream not available (${widget.audioUrl}): $e');
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
    final isDark = widget.isDarkTheme;
    final primaryAccent = isDark ? const Color(0xFF38BDF8) : AppTheme.primaryColor;
    final textTitleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textSubColor = isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary;
    final cardBg = isDark ? Colors.white.withAlpha(12) : Colors.white;
    final cardBorder = isDark ? Colors.white.withAlpha(25) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? []
            : [
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
                  color: primaryAccent.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.audiotrack_rounded, color: primaryAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title.isNotEmpty ? widget.title : 'Audio Player',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textTitleColor,
                      ),
                    ),
                    StreamBuilder<Duration?>(
                      stream: _player.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? _player.duration;
                        if (duration != null && duration.inSeconds > 0) {
                          return Text(
                            'Duration: ${_formatDuration(duration)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSubColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }
                        return Text(
                          'Ready to play',
                          style: TextStyle(fontSize: 12, color: textSubColor),
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
                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.orange),
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
                  progressBarColor: primaryAccent,
                  baseBarColor: isDark ? Colors.white.withAlpha(25) : const Color(0xFFE2E8F0),
                  bufferedBarColor: isDark ? Colors.white.withAlpha(45) : const Color(0xFFCBD5E1),
                  thumbColor: primaryAccent,
                  thumbRadius: 7.0,
                  timeLabelLocation: TimeLabelLocation.sides,
                  timeLabelTextStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSubColor,
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
                  icon: const Icon(Icons.replay_10_rounded),
                  iconSize: 24,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
                  tooltip: 'Rewind 10s',
                ),
                const SizedBox(width: 14),

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
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryAccent,
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        ),
                      );
                    } else if (playing != true) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withAlpha(isDark ? 80 : 50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton.filled(
                          onPressed: _player.play,
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: primaryAccent,
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                      );
                    } else {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryAccent.withAlpha(isDark ? 80 : 50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton.filled(
                          onPressed: _player.pause,
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: primaryAccent,
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                          icon: const Icon(Icons.pause_rounded),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 14),

                // Forward 10 seconds
                IconButton(
                  onPressed: () {
                    final total = _player.duration ?? Duration.zero;
                    final newPos = _player.position + const Duration(seconds: 10);
                    _player.seek(newPos > total ? total : newPos);
                  },
                  icon: const Icon(Icons.forward_10_rounded),
                  iconSize: 24,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textSecondary,
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
