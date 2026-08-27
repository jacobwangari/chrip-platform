import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../authentication/domain/user_model.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/search_controller.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchController _controller;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Scoped to this screen — created fresh each time search is
    // opened, so a stale query/results list never carries over from
    // a previous visit.
    _controller = Get.put(SearchController());
  }

  @override
  void dispose() {
    _textController.dispose();
    Get.delete<SearchController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search people',
            border: InputBorder.none,
          ),
          onChanged: _controller.onQueryChanged,
        ),
      ),
      body: Obx(() {
        if (_controller.query.value.trim().isEmpty) {
          return Center(
            child: Text('Search by username or display name',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }

        if (_controller.isLoading.value && _controller.results.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.results.isEmpty) {
          return Center(
            child: Text('No one found', style: TextStyle(color: Colors.grey.shade600)),
          );
        }

        return Column(
          children: [
            InlineErrorText(message: _controller.errorMessage.value),
            Expanded(
              child: ListView.separated(
                itemCount: _controller.results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = _controller.results[index];
                  return _SearchResultTile(
                    user: user,
                    onTap: () => Get.to(() => ProfileScreen(username: user.username)),
                    onToggleFollow: () => _controller.toggleFollow(user),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;

  const _SearchResultTile({required this.user, required this.onTap, required this.onToggleFollow});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null
            ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('@${user.username}'),
      trailing: OutlinedButton(
        onPressed: onToggleFollow,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
        ),
        child: Text(user.isFollowing ? 'Unfollow' : 'Follow', style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}