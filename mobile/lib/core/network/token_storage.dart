import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Wraps flutter_secure_storage so the rest of the app never touches
/// the storage API directly — makes it easy to swap implementations
/// or mock in tests.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: AppConstants.accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: AppConstants.refreshTokenKey);

  Future<void> updateAccessToken(String access) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
  }

  Future<void> clear() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  Future<bool> get hasTokens async => (await accessToken) != null;
}
