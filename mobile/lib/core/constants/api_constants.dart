class ApiConstants {
  // Active Cloudflare HTTPS Tunnel (Works everywhere on Wi-Fi & 4G/5G mobile data)
  static const String serverBaseUrl = 'https://same-inspiration-dim-show.trycloudflare.com';
  static const String baseUrl = '$serverBaseUrl/api';

  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  static const String meetings = '/meetings';
}
