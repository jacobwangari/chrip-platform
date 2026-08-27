import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/inline_error_text.dart';
import '../../../shared/widgets/tweet_card.dart';
import '../../authentication/domain/auth_controller.dart';
import '../domain/tweet_detail_controller.dart';
import 'compose_screen.dart';

class TweetDetailScreen extends StatefulWidget {
  final int tweetId;

  const TweetDetailScreen({super.key, required this.tweetId});

  @override
  State<TweetDetailScreen> createState() => _TweetDetailScreenState();
}

class _TweetDetailScreenState extends State<TweetDetailScreen> {
  late final TweetDetailController _controller;
  final _auth = Get.find<AuthController>();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Tagged by tweet id so opening a second thread (e.g. tapping a
    // reply to open ITS thread) never reuses this screen's state —
    // same pattern as ProfileController.
    _controller = Get.put(TweetDetailController(tweetId: widget.tweetId), tag: 'tweet-${widget.tweetId}');

    _scrollController.addListener(() {
      final nearBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300;
      if (nearBottom) _controller.fetchMoreReplies();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    Get.delete<TweetDetailController>(tag: 'tweet-${widget.tweetId}');
    super.dispose();
  }

  void _openReplyCompose() {
    final tweet = _controller.tweet.value;
    if (tweet == null) return;

    final targetId = tweet.isRetweet ? tweet.retweetOfId! : tweet.id;
    final targetUsername = tweet.isRetweet ? tweet.originalAuthor!.username : tweet.author.username;

    Get.to(() => ComposeScreen(
          parentId: targetId,
          replyingToUsername: targetUsername,
          onPosted: _controller.afterReplyPosted,
        ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tweet?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _controller.deleteTweet();
      if (success && mounted) Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tweet')),
      body: Obx(() {
        final tweet = _controller.tweet.value;

        if (_controller.isLoadingTweet.value && tweet == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (tweet == null) {
          return Center(child: InlineErrorText(message: _controller.errorMessage.value));
        }

        final isOwnTweet = tweet.author.id == _auth.currentUser.value?.id;

        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            controller: _scrollController,
            children: [
              // Main tweet — no onReply/onRetweet/onToggleLike wired to
              // navigate anywhere further; this IS the destination.
              TweetCard(
                tweet: tweet,
                isOwnTweet: isOwnTweet,
                onDelete: isOwnTweet ? _confirmDelete : null,
                onToggleLike: _controller.toggleLike,
                onRetweet: () => _controller.retweet(tweet.retweetOfId ?? tweet.id),
                onReply: _openReplyCompose,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Replies',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                ),
              ),
              if (_controller.isLoadingReplies.value && _controller.replies.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_controller.replies.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No replies yet — be the first.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                )
              else
                ..._controller.replies.map((reply) {
                  final isOwnReply = reply.author.id == _auth.currentUser.value?.id;
                  return TweetCard(
                    tweet: reply,
                    isOwnTweet: isOwnReply,
                    onDelete: null, // deleting a reply from here isn't wired yet — small follow-up
                    onToggleLike: null,
                    onRetweet: null,
                    onReply: () => Get.to(() => TweetDetailScreen(tweetId: reply.id)),
                  );
                }),
              if (_controller.hasMoreReplies)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _openReplyCompose,
        child: const Icon(Icons.reply),
      ),
    );
  }
}