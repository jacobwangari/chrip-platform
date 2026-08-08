import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../authentication/domain/user_model.dart';

class UserException implements Exception {
  final String message;
  UserException(this.message);
  @override
  String toString() => message;
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

  Future<List<UserModel>> fetchFollowers(String username) async {
    try {
      final response = await _dio.get('/users/$username/followers/');
      return (response.data['results'] as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw UserException(_extractError(e));
    }
  }

  Future<List<UserModel>> fetchFollowing(String username) async {
    try {
      final response = await _dio.get('/users/$username/following/');
      return (response.data['results'] as List)
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