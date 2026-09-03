class ApiConstants {
  // Ultra-Fast Cloudflare Enterprise HTTPS Tunnel (Zero USB cable, works on all Wi-Fi & 4G/5G networks)
  static const String serverBaseUrl = 'https://acts-prince-rate-protein.trycloudflare.com';
  static const String baseUrl = '$serverBaseUrl/api';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String meetings = '/meetings';
}
