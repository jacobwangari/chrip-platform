import '../../authentication/domain/user_model.dart';

class MediaModel {
  final int id;
  final String url;
  final String mediaType; // IMAGE | GIF | VIDEO
  final int position;

  MediaModel({required this.id, required this.url, required this.mediaType, required this.position});

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    return MediaModel(
      id: json['id'] as int,
      url: json['url'] as String,
      mediaType: json['media_type'] as String,
      position: json['position'] as int? ?? 0,
    );
  }
}

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
  final int likeCount;
  final bool isLiked;
  final DateTime createdAt;
  final List<MediaModel> media;

  // Populated only when isRetweet is true — the tweet actually being
  // shown in the card. Kept flat (not a nested TweetModel) since the
  // backend guarantees retweet_of always points to a true original,
  // never another retweet, so no recursive nesting is needed.
  final UserModel? originalAuthor;
  final String? originalContent;
  final DateTime? originalCreatedAt;

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
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
    required this.media,
    this.originalAuthor,
    this.originalContent,
    this.originalCreatedAt,
  });

  factory TweetModel.fromJson(Map<String, dynamic> json) {
    final original = json['original_tweet'] as Map<String, dynamic>?;

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
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      media: (json['media'] as List<dynamic>? ?? [])
          .map((m) => MediaModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      originalAuthor:
          original != null ? UserModel.fromJson(original['author'] as Map<String, dynamic>) : null,
      originalContent: original != null ? original['content'] as String? : null,
      originalCreatedAt:
          original != null ? DateTime.parse(original['created_at'] as String) : null,
    );
  }

  /// Used for optimistic like/unlike and reply-count UI updates
  /// without a full refetch.
  TweetModel copyWith({bool? isLiked, int? likeCount, int? replyCount}) {
    return TweetModel(
      id: id,
      author: author,
      content: content,
      visibility: visibility,
      parentId: parentId,
      retweetOfId: retweetOfId,
      isRetweet: isRetweet,
      replyCount: replyCount ?? this.replyCount,
      retweetCount: retweetCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt,
      media: media,
      originalAuthor: originalAuthor,
      originalContent: originalContent,
      originalCreatedAt: originalCreatedAt,
    );
  }
}