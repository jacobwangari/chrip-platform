class UserModel {
  final int id;
  final String username;
  final String displayName;
  final String email;
  final String bio;
  final String? avatarUrl;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.avatarUrl,
    required this.isVerified,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String? ?? '',
      email: json['email'] as String,
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}
