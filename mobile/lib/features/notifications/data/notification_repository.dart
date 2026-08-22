import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/notification_model.dart';

class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);
  @override
  String toString() => message;
}

/// A page of notifications plus the cursor URL for the next page, if
/// any — same shape as TweetPage, since DRF's CursorPagination returns
/// `next` as a full absolute URL in both cases.
class NotificationPage {
  final List<NotificationModel> notifications;
  final String? nextUrl;

  NotificationPage({required this.notifications, required this.nextUrl});
}

class NotificationRepository {
  final Dio _dio = DioClient().dio;

  Future<NotificationPage> fetchNotifications({String? cursorUrl}) async {
    try {
      final response = cursorUrl != null
          ? await _dio.get(cursorUrl)
          : await _dio.get('/notifications/');

      final results = (response.data['results'] as List)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return NotificationPage(notifications: results, nextUrl: response.data['next'] as String?);
    } on DioException catch (e) {
      throw NotificationException(_extractError(e));
    }
  }

  Future<NotificationModel> markAsRead(int id) async {
    try {
      final response = await _dio.patch('/notifications/$id/read/');
      return NotificationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NotificationException(_extractError(e));
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dio.post('/notifications/read-all/');
    } on DioException catch (e) {
      throw NotificationException(_extractError(e));
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