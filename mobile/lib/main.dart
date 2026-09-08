import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/meetings/screens/meeting_details_screen.dart';
import 'features/splash/screens/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      child: MinuteCraftApp(),
    ),
  );
}

class MinuteCraftApp extends ConsumerWidget {
  const MinuteCraftApp({super.key});

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
