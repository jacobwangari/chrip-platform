import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/network/token_storage.dart';
import '../domain/user_model.dart';

/// Thin exception type so the domain/presentation layers can show a
/// clean message instead of parsing Dio's error shape directly.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final Dio _dio = DioClient().dio;

  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _dio.post('/auth/register/', data: {
        'username': username,
        'email': email,
        'password': password,
        'display_name': displayName,
      });

      await TokenStorage.instance.saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
      );

      return UserModel.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<UserModel> login({required String username, required String password}) async {
    try {
      final response = await _dio.post('/auth/login/', data: {
        'username': username,
        'password': password,
      });

      await TokenStorage.instance.saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
      );

      return fetchMe();
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<UserModel> fetchMe() async {
    try {
      final response = await _dio.get('/auth/me/');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/auth/me/', data: data);
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStorage.instance.refreshToken;
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout/', data: {'refresh': refresh});
      } on DioException {
        // Even if the server call fails (e.g. offline), still clear
        // local tokens so the user is logged out on this device.
      }
    }
    await TokenStorage.instance.clear();
  }

  String _extractError(DioException e) {
    // TEMPORARY debug logging — remove once the root cause is found.
    // ignore: avoid_print
    print('DioException type: ${e.type}');
    // ignore: avoid_print
    print('DioException message: ${e.message}');
    // ignore: avoid_print
    print('DioException requestOptions.uri: ${e.requestOptions.uri}');

    final data = e.response?.data;
    if (data is Map && data.isNotEmpty) {
      final firstKey = data.keys.first;
      final firstValue = data[firstKey];
      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.first.toString();
      }
      return firstValue.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}