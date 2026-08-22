import 'package:get/get.dart';

import '../../../core/network/token_storage.dart';
import '../data/notification_repository.dart';
import 'notification_model.dart';

/// Registered once in main.dart (like AuthController) rather than
/// created per-screen — an unread badge needs to be visible from the
/// dashboard without first opening the notifications screen.
class NotificationController extends GetxController {
  final NotificationRepository _repository = NotificationRepository();

  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;

  String? _nextUrl;
  bool get hasMore => _nextUrl != null;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    // Guarded — this controller is created in main.dart before login,
    // so onInit can fire before any token exists. Without this check,
    // the very first request at cold start would be a guaranteed 401.
    // DashboardScreen calls fetchInitial() again once actually
    // authenticated, which is the real trigger for populating data.
    _fetchIfAuthenticated();
  }

  Future<void> _fetchIfAuthenticated() async {
    final hasTokens = await TokenStorage.instance.hasTokens;
    if (hasTokens) {
      fetchInitial();
    }
  }

  Future<void> fetchInitial() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final page = await _repository.fetchNotifications();
      notifications.assignAll(page.notifications);
      _nextUrl = page.nextUrl;
    } on NotificationException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => fetchInitial();

  Future<void> fetchMore() async {
    if (!hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      final page = await _repository.fetchNotifications(cursorUrl: _nextUrl);
      notifications.addAll(page.notifications);
      _nextUrl = page.nextUrl;
    } on NotificationException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> markAsRead(int id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1 || notifications[index].isRead) return;

    // Optimistic update — flip immediately, revert on failure.
    final original = notifications[index];
    notifications[index] = original.copyWith(isRead: true);

    try {
      final updated = await _repository.markAsRead(id);
      final currentIndex = notifications.indexWhere((n) => n.id == id);
      if (currentIndex != -1) {
        notifications[currentIndex] = updated;
      }
    } on NotificationException catch (e) {
      final currentIndex = notifications.indexWhere((n) => n.id == id);
      if (currentIndex != -1) {
        notifications[currentIndex] = original;
      }
      errorMessage.value = e.message;
    }
  }

  Future<void> markAllAsRead() async {
    if (unreadCount == 0) return;

    // Optimistic — flip everything, revert only on failure.
    final originalList = List<NotificationModel>.from(notifications);
    notifications.assignAll(notifications.map((n) => n.copyWith(isRead: true)));

    try {
      await _repository.markAllAsRead();
    } on NotificationException catch (e) {
      notifications.assignAll(originalList);
      errorMessage.value = e.message;
    }
  }
}