import '../../authentication/domain/user_model.dart';

enum NotificationType { like, retweet, follow, reply, mention, unknown }

NotificationType _typeFromString(String value) {
  switch (value) {
    case 'LIKE':
      return NotificationType.like;
    case 'RETWEET':
      return NotificationType.retweet;
    case 'FOLLOW':
      return NotificationType.follow;
    case 'REPLY':
      return NotificationType.reply;
    case 'MENTION':
      return NotificationType.mention;
    default:
      return NotificationType.unknown;
  }
}

class NotificationModel {
  final int id;
  final UserModel actor;
  final NotificationType type;
  final int? targetTweetId;
  final String? targetTweetContent;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.actor,
    required this.type,
    required this.targetTweetId,
    required this.targetTweetContent,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      actor: UserModel.fromJson(json['actor'] as Map<String, dynamic>),
      type: _typeFromString(json['type'] as String? ?? ''),
      targetTweetId: json['target_tweet_id'] as int?,
      targetTweetContent: json['target_tweet_content'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Used for optimistic "mark as read" UI updates without a refetch.
  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      actor: actor,
      type: type,
      targetTweetId: targetTweetId,
      targetTweetContent: targetTweetContent,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// Human-readable summary — kept here (not in the widget) so it's
  /// reusable anywhere a notification is rendered, not just the list screen.
  String get message {
    switch (type) {
      case NotificationType.like:
        return '${actor.displayName} liked your tweet';
      case NotificationType.retweet:
        return '${actor.displayName} retweeted your tweet';
      case NotificationType.follow:
        return '${actor.displayName} followed you';
      case NotificationType.reply:
        return '${actor.displayName} replied to your tweet';
      case NotificationType.mention:
        return '${actor.displayName} mentioned you';
      case NotificationType.unknown:
        return '${actor.displayName} interacted with your account';
    }
  }
}