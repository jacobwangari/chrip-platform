import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/notification_controller.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _controller = Get.find<NotificationController>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final nearBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300;
      if (nearBottom) _controller.fetchMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.retweet:
        return Icons.repeat;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.reply:
        return Icons.chat_bubble;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.unknown:
        return Icons.notifications;
    }
  }

  Color _colorFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.retweet:
        return Colors.green;
      case NotificationType.follow:
        return Colors.blue;
      case NotificationType.reply:
      case NotificationType.mention:
      case NotificationType.unknown:
        return Colors.grey.shade700;
    }
  }

  void _handleTap(NotificationModel notification) {
    _controller.markAsRead(notification.id);
    // Only FOLLOW notifications have a clear single destination right
    // now (the actor's profile) — likes/retweets/replies would ideally
    // open the target tweet, but there's no tweet detail screen yet,
    // so tapping those just marks them read for now.
    if (notification.type == NotificationType.follow) {
      Get.to(() => ProfileScreen(username: notification.actor.username));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Obx(() => TextButton(
                onPressed: _controller.unreadCount == 0 ? null : _controller.markAllAsRead,
                child: const Text('Mark all read'),
              )),
        ],
      ),
      body: Column(
        children: [
          Obx(() => InlineErrorText(message: _controller.errorMessage.value)),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.notifications.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_controller.notifications.isEmpty) {
                return const Center(child: Text('No notifications yet.'));
              }

              return RefreshIndicator(
                onRefresh: _controller.refresh,
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _controller.notifications.length + (_controller.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _controller.notifications.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }

                    final notification = _controller.notifications[index];

                    return Container(
                      color: notification.isRead ? null : Colors.blue.withOpacity(0.06),
                      child: ListTile(
                        onTap: () => _handleTap(notification),
                        leading: CircleAvatar(
                          backgroundColor: _colorFor(notification.type).withOpacity(0.15),
                          backgroundImage: notification.actor.avatarUrl != null
                              ? NetworkImage(notification.actor.avatarUrl!)
                              : null,
                          child: notification.actor.avatarUrl == null
                              ? Icon(_iconFor(notification.type),
                                  color: _colorFor(notification.type), size: 20)
                              : null,
                        ),
                        title: Text(notification.message),
                        subtitle: notification.targetTweetContent != null &&
                                notification.targetTweetContent!.isNotEmpty
                            ? Text(
                                notification.targetTweetContent!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}