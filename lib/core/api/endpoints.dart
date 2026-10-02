/// API endpoint constants for Falcon Intel backend.
/// All paths match exactly what the web portal uses.
class Endpoints {
  static const String baseUrl = 'https://falconintel.org';
  static const String apiBase = '$baseUrl/api';

  // Auth (same as web)
  static const String login = '/auth/login';
  static const String verify2fa = '/auth/verify-2fa';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // News — web uses /news/nationwide/automatic?hours_back=N
  static const String newsAutomatic = '/news/nationwide/automatic';
  static const String newsRefresh = '/news/refresh';
  static const String newsThreats = '/news/threats';

  // Social Media — web uses /social-media/threats and /social-media/overview
  static const String socialOverview = '/social-media/overview';
  static const String socialThreats = '/social-media/threats';
  static const String socialTrending = '/social-media/trending';

  // Alerts — web uses /alerts?severity=X&status=Y, /alerts/count, /alerts/update-status
  static const String alerts = '/alerts';
  static const String alertsCount = '/alerts/count';
  static const String alertsStats = '/alerts/stats';
  static const String alertsUpdateStatus = '/alerts/update-status';

  // Watches
  static const String watches = '/watches/';

  // Modules
  static const String myModules = '/modules/me';

  // Dashboard
  static const String dashboard = '/dashboard/';

  // AI Analysis
  static const String aiAnalyze = '/ai/analyze';

  // Preferences (synced with web)
  static const String preferences = '/preferences/';
}