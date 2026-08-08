/// Central place for string keys used across the app — avoids typo'd
/// magic strings scattered through storage/network code.
class AppConstants {
  AppConstants._();

  // Secure storage keys
  static const accessTokenKey = 'chirp_access_token';
  static const refreshTokenKey = 'chirp_refresh_token';

  // .env keys
  static const apiBaseUrlEnvKey = 'API_BASE_URL';
  static const defaultApiBaseUrl = 'http://10.0.2.2:9000/api';
}
