import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../authentication/domain/auth_controller.dart';
import '../domain/profile_controller.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;
  final _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    // Tagged by username so navigating between two different profiles
    // never reuses stale state from the previous one. Created here
    // (not in build()) so controller setup never runs mid-build.
    _controller = Get.put(ProfileController(username: widget.username), tag: widget.username);
  }

  @override
  void dispose() {
    // Tagged controllers don't get cleaned up automatically like
    // route-scoped ones — remove it so repeated profile visits don't
    // accumulate controllers for every username ever viewed.
    Get.delete<ProfileController>(tag: widget.username);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.user.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = _controller.user.value;
        if (user == null) {
          return Center(child: InlineErrorText(message: _controller.errorMessage.value));
        }

        final isOwnProfile = user.id == _auth.currentUser.value?.id;

        return RefreshIndicator(
          onRefresh: _controller.loadProfile,
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
              InlineErrorText(message: _controller.errorMessage.value),
              SizedBox(
                width: double.infinity,
                child: isOwnProfile
                    ? PrimaryButton(
                        label: 'Edit Profile',
                        isLoading: false,
                        onPressed: () async {
                          await Get.to(() => const EditProfileScreen());
                          // Own profile is served from the same user
                          // data as AuthController.currentUser, so a
                          // save there won't auto-reflect here unless
                          // we refetch — cheap, and keeps this screen
                          // always showing the latest edit on return.
                          _controller.loadProfile();
                        },
                      )
                    : PrimaryButton(
                        label: user.isFollowing ? 'Unfollow' : 'Follow',
                        isLoading: _controller.isTogglingFollow.value,
                        onPressed: _controller.toggleFollow,
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}