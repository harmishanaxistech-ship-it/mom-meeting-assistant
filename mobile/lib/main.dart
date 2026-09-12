import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/meetings/screens/meeting_details_screen.dart';
import 'features/splash/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  
  // Initialize notification service
  await NotificationService().initialize();

  NotificationService.onNotificationTapped = (meetingId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MeetingDetailsScreen(meetingId: meetingId),
      ),
    );
  };

  runApp(
    const ProviderScope(
      child: NoteAXApp(),
    ),
  );
}

class NoteAXApp extends ConsumerWidget {
  const NoteAXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
