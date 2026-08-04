import '../../authentication/domain/user_model.dart';

class TweetModel {
  final int id;
  final UserModel author;
  final String content;
  final String visibility;
  final int? parentId;
  final int? retweetOfId;
  final bool isRetweet;
  final int replyCount;
  final int retweetCount;
  final DateTime createdAt;

  TweetModel({
    required this.id,
    required this.author,
    required this.content,
    required this.visibility,
    required this.parentId,
    required this.retweetOfId,
    required this.isRetweet,
    required this.replyCount,
    required this.retweetCount,
    required this.createdAt,
  });

  factory TweetModel.fromJson(Map<String, dynamic> json) {
    return TweetModel(
      id: json['id'] as int,
      author: UserModel.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      parentId: json['parent'] as int?,
      retweetOfId: json['retweet_of'] as int?,
      isRetweet: json['is_retweet'] as bool? ?? false,
      replyCount: json['reply_count'] as int? ?? 0,
      retweetCount: json['retweet_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
