import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';
import 'notification_service.dart';
import '../../features/meetings/controllers/meeting_controller.dart';

class BackgroundProcessingTask {
  final String meetingId;
  final String meetingTitle;
  final DateTime startedAt;

  BackgroundProcessingTask({
    required this.meetingId,
    required this.meetingTitle,
    required this.startedAt,
  });
}

class BackgroundProcessingService {
  static final BackgroundProcessingService _instance = BackgroundProcessingService._internal();
  factory BackgroundProcessingService() => _instance;
  BackgroundProcessingService._internal();

  final Map<String, BackgroundProcessingTask> _activeTasks = {};
  Timer? _pollingTimer;
  Ref? _ref;

  void attachRef(Ref ref) {
    _ref = ref;
  }

  bool isMeetingProcessing(String meetingId) {
    return _activeTasks.containsKey(meetingId);
  }

  void startTracking({
    required String meetingId,
    required String meetingTitle,
  }) {
    if (_activeTasks.containsKey(meetingId)) return;

    _activeTasks[meetingId] = BackgroundProcessingTask(
      meetingId: meetingId,
      meetingTitle: meetingTitle,
      startedAt: DateTime.now(),
    );

    _ensurePollingActive();
  }

  void stopTracking(String meetingId) {
    _activeTasks.remove(meetingId);
    if (_activeTasks.isEmpty) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void _ensurePollingActive() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_activeTasks.isEmpty) {
        timer.cancel();
        _pollingTimer = null;
        return;
      }

      final client = ApiClient();
      final taskIds = _activeTasks.keys.toList();

      for (final id in taskIds) {
        final task = _activeTasks[id];
        if (task == null) continue;

        try {
          final res = await client.dio.get(
            '${ApiConstants.meetings}/$id/processing-status',
          );

          if (res.data['success'] == true) {
            final data = res.data['data'];
            final currentStage = data['currentStage'] as String? ?? '';
            final meetingStatus = data['meetingStatus'] as String? ?? '';

            if (currentStage == 'completed' || meetingStatus == 'completed') {
              stopTracking(id);

              await NotificationService().showProcessingCompletedNotification(
                meetingId: id,
                meetingTitle: task.meetingTitle,
              );

              _ref?.read(meetingControllerProvider.notifier).fetchMeetings();
            } else if (currentStage == 'failed' || meetingStatus == 'failed') {
              stopTracking(id);

              final errorMsg = data['errorMessage'] as String?;
              await NotificationService().showProcessingFailedNotification(
                meetingId: id,
                meetingTitle: task.meetingTitle,
                reason: errorMsg,
              );

              _ref?.read(meetingControllerProvider.notifier).fetchMeetings();
            } else {
              // Ongoing progress notification
              final progress = data['progressPercentage'] as int? ?? 10;
              final stageDesc = data['stageDescription'] as String? ?? 'Processing...';
              
              await NotificationService().showProgressNotification(
                meetingId: id,
                meetingTitle: task.meetingTitle,
                progress: progress,
                status: stageDesc,
              );
            }
          }
        } catch (_) {
          // Ignore transient network errors
        }
      }
    });
  }
}

final backgroundProcessingProvider = Provider<BackgroundProcessingService>((ref) {
  final service = BackgroundProcessingService();
  service.attachRef(ref);
  return service;
});