import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/app_constants.dart';
import 'token_storage.dart';

/// A callback the app can hook into to react to a forced logout
/// (e.g. navigate to the login screen) without DioClient depending
/// on navigation/UI code directly.
typedef OnAuthExpired = void Function();

class DioClient {
  DioClient._internal();
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio = _build();
  OnAuthExpired? onAuthExpired;

  // Dio used only for the refresh call itself, so it never gets
  // caught in its own interceptor loop.
  final Dio _refreshDio = Dio();

  bool _isRefreshing = false;
  final List<void Function()> _pendingRequests = [];

  String get _baseUrl =>
      dotenv.env[AppConstants.apiBaseUrlEnvKey] ?? AppConstants.defaultApiBaseUrl;

  Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.instance.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        final isUnauthorized = error.response?.statusCode == 401;
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/login') ||
            error.requestOptions.path.contains('/auth/register') ||
            error.requestOptions.path.contains('/auth/refresh');

        if (!isUnauthorized || isAuthEndpoint) {
          return handler.next(error);
        }

        try {
          final newAccessToken = await _refreshAccessToken();
          if (newAccessToken == null) {
            await _forceLogout();
            return handler.next(error);
          }

          // Retry the original request with the fresh token.
          final retryOptions = error.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final response = await dio.fetch(retryOptions);
          return handler.resolve(response);
        } catch (_) {
          await _forceLogout();
          return handler.next(error);
        }
      },
    ));

    return dio;
  }

  /// Ensures only one refresh call happens at a time, even if several
  /// requests 401 concurrently.
  Future<String?> _refreshAccessToken() async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _pendingRequests.add(completer.complete);
      await completer.future;
      return TokenStorage.instance.accessToken;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await TokenStorage.instance.refreshToken;
      if (refreshToken == null) return null;

      final response = await _refreshDio.post(
        '$_baseUrl/auth/refresh/',
        data: {'refresh': refreshToken},
      );

      final newAccess = response.data['access'] as String;
      await TokenStorage.instance.updateAccessToken(newAccess);
      return newAccess;
    } catch (_) {
      return null;
    } finally {
      _isRefreshing = false;
      for (final resume in _pendingRequests) {
        resume();
      }
      _pendingRequests.clear();
    }
  }

  Future<void> _forceLogout() async {
    await TokenStorage.instance.clear();
    onAuthExpired?.call();
  }
}
