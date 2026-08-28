import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../authentication/domain/user_model.dart';

class UserException implements Exception {
  final String message;
  UserException(this.message);
  @override
  String toString() => message;
}

/// A page of users plus the cursor URL for the next page, if any —
/// same shape as TweetPage in the dashboard feature.
class UserPage {
  final List<UserModel> users;
  final String? nextUrl;

  UserPage({required this.users, required this.nextUrl});
}

class UserRepository {
  final Dio _dio = DioClient().dio;

  Future<UserModel> fetchUser(String username) async {
    try {
      final response = await _dio.get('/users/$username/');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  Future<UserModel> follow(String username) async {
    try {
      final response = await _dio.post('/users/$username/follow/');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  Future<UserModel> unfollow(String username) async {
    try {
      final response = await _dio.delete('/users/$username/follow/');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  /// Paginated — the previous version of this method dropped the
  /// `next` cursor, silently capping the followers list at one page
  /// (the same bug that fetchReplies had before it was fixed).
  Future<UserPage> fetchFollowers(String username, {String? cursorUrl}) async {
    try {
      final response =
          cursorUrl != null ? await _dio.get(cursorUrl) : await _dio.get('/users/$username/followers/');
      final results = (response.data['results'] as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return UserPage(users: results, nextUrl: response.data['next'] as String?);
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  Future<UserPage> fetchFollowing(String username, {String? cursorUrl}) async {
    try {
      final response =
          cursorUrl != null ? await _dio.get(cursorUrl) : await _dio.get('/users/$username/following/');
      final results = (response.data['results'] as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return UserPage(users: results, nextUrl: response.data['next'] as String?);
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  /// GET /users/search/?q=... returns a plain JSON array, NOT the
  /// usual {results, next} pagination envelope — the backend view
  /// disables pagination for search (relevance-style ordering isn't
  /// compatible with cursor pagination's monotonic-field requirement).
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get('/users/search/', queryParameters: {'q': query});
      return (response.data as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
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