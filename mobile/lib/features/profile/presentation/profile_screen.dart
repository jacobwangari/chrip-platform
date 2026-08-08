import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../authentication/domain/auth_controller.dart';
import '../domain/profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    // Tagged by username so navigating between two different profiles
    // never reuses stale state from the previous one.
    final controller = Get.put(ProfileController(username: username), tag: username);
    final auth = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: Obx(() {
        if (controller.isLoading.value && controller.user.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = controller.user.value;
        if (user == null) {
          return Center(child: InlineErrorText(message: controller.errorMessage.value));
        }

        final isOwnProfile = user.id == auth.currentUser.value?.id;

        return RefreshIndicator(
          onRefresh: controller.loadProfile,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(user.displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text('@${user.username}', style: TextStyle(color: Colors.grey.shade600)),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(user.bio),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${user.followingCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text('Following', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 20),
                  Text('${user.followerCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text('Followers', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 20),
              InlineErrorText(message: controller.errorMessage.value),
              if (!isOwnProfile)
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: user.isFollowing ? 'Unfollow' : 'Follow',
                    isLoading: controller.isTogglingFollow.value,
                    onPressed: controller.toggleFollow,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}