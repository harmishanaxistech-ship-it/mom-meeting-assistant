import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Callback when user taps a notification with payload (e.g. meetingId)
  static void Function(String meetingId)? onNotificationTapped;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          onNotificationTapped?.call(response.payload!);
        }
      },
    );

    // Create high-importance Android Notification Channel
    const androidChannel = AndroidNotificationChannel(
      'mom_processing_channel',
      'Meeting Processing Updates',
      description: 'Notifications when audio transcription & AI MOM generation complete',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> showProcessingCompletedNotification({
    required String meetingId,
    required String meetingTitle,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'mom_processing_channel',
      'Meeting Processing Updates',
      channelDescription: 'Notifications when audio transcription & AI MOM generation complete',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1E3A8A),
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final notificationId = meetingId.hashCode.abs() % 100000;

    await _notificationsPlugin.show(
      id: notificationId,
      title: '🎯 MOM Ready: $meetingTitle',
      body: 'Your AI Minutes of Meeting have been generated! Tap to view.',
      notificationDetails: notificationDetails,
      payload: meetingId,
    );
  }

  Future<void> showProcessingFailedNotification({
    required String meetingId,
    required String meetingTitle,
    String? reason,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'mom_processing_channel',
      'Meeting Processing Updates',
      channelDescription: 'Notifications when audio transcription & AI MOM generation complete',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFEF4444),
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    final notificationId = meetingId.hashCode.abs() % 100000;

    await _notificationsPlugin.show(
      id: notificationId,
      title: '⚠️ MOM Generation Failed: $meetingTitle',
      body: reason ?? 'Could not transcribe or process this meeting audio.',
      notificationDetails: notificationDetails,
      payload: meetingId,
    );
  }
}
