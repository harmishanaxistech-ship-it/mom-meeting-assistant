class ApiConstants {
  // Option 1: Local Wi-Fi Testing (Mac IP Address)
  // static const String serverBaseUrl = 'https://noteaxapi.anaxistech.com';
  
  // Option 2: Ngrok URL (Paste your Ngrok HTTPS link here)
  // static const String serverBaseUrl = 'https://noteaxapi.anaxistech.com';
  
  // Option 3: Live Server URL
  static const String serverBaseUrl = 'https://noteaxapi.anaxistech.com';

  static const String baseUrl = '$serverBaseUrl/api';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String meetings = '/meetings';

  // 🏢 White-Label Company Code (Change this for each app clone)
  static const String companyCode = 'NOBESITY';
}
