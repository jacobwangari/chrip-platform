class UserModel {
  final int id;
  final String username;
  final String displayName;
  final String email;
  final String bio;
  final String? avatarUrl;
  final bool isVerified;
  final String location;
  final String website;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.avatarUrl,
    required this.isVerified,
    this.location = '',
    this.website = '',
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      location: json['location'] as String? ?? '',
      website: json['website'] as String? ?? '',
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  /// Used for optimistic follow/unfollow UI updates without a refetch.
  UserModel copyWith({bool? isFollowing, int? followerCount}) {
    return UserModel(
      id: id,
      username: username,
      displayName: displayName,
      email: email,
      bio: bio,
      avatarUrl: avatarUrl,
      isVerified: isVerified,
      location: location,
      website: website,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}