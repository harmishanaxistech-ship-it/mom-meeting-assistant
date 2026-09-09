class ApiConstants {
  // --- Local Testing Backend URLs ---
  // Direct USB connection (via adb reverse):
  static const String serverBaseUrl = 'http://127.0.0.1:5001';
  // Wi-Fi Local IP:
  // static const String serverBaseUrl = 'http://192.168.1.18:5001';
  // Use 10.0.2.2 for Android Studio Emulator:
  // static const String serverBaseUrl = 'http://10.0.2.2:5001';
  // Use Live Server:
  // static const String serverBaseUrl = 'https://noteaxapi.anaxistech.com';

  static const String baseUrl = '$serverBaseUrl/api';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String meetings = '/meetings';
}
