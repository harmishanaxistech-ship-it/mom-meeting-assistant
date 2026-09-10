class ApiConstants {
  // Local USB Testing via adb reverse:
  // static const String serverBaseUrl = 'http://127.0.0.1:5001';
  // Live Server URL:
  static const String serverBaseUrl = 'https://noteaxapi.anaxistech.com';
  // static const String serverBaseUrl = 'http://10.0.2.2:5001'; // Android Emulator

  static const String baseUrl = '$serverBaseUrl/api';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String meetings = '/meetings';
}
