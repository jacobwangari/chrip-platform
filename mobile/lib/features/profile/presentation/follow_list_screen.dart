import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../domain/follow_list_controller.dart';
import 'profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String username;
  final FollowListMode mode;

  const FollowListScreen({super.key, required this.username, required this.mode});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final FollowListController _controller;
  final _scrollController = ScrollController();

  String get _tag => '${widget.username}-${widget.mode.name}';

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      FollowListController(username: widget.username, mode: widget.mode),
      tag: _tag,
    );

    _scrollController.addListener(() {
      final nearBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300;
      if (nearBottom) _controller.fetchMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    Get.delete<FollowListController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.mode == FollowListMode.followers ? 'Followers' : 'Following';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.users.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.users.isEmpty) {
          return Center(
            child: Text(
              widget.mode == FollowListMode.followers ? 'No followers yet.' : 'Not following anyone yet.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: Column(
            children: [
              InlineErrorText(message: _controller.errorMessage.value),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: _controller.users.length + (_controller.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _controller.users.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }

                    final user = _controller.users[index];
                    return ListTile(
                      onTap: () => Get.to(() => ProfileScreen(username: user.username)),
                      leading: CircleAvatar(
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null
                            ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        user.bio.isNotEmpty ? user.bio : '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}