import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../features/dashboard/domain/tweet_model.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// Displays a single tweet — reused in the feed, replies, and (later)
/// profile timeline, so tweet layout only needs to be built once.
class TweetCard extends StatelessWidget {
  final TweetModel tweet;
  final bool isOwnTweet;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleLike;

  const TweetCard({
    super.key,
    required this.tweet,
    this.isOwnTweet = false,
    this.onDelete,
    this.onToggleLike,
  });

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: tweet.author.avatarUrl != null
                      ? NetworkImage(tweet.author.avatarUrl!)
                      : null,
                  child: tweet.author.avatarUrl == null
                      ? Text(tweet.author.displayName.isNotEmpty
                          ? tweet.author.displayName[0].toUpperCase()
                          : '?')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfile(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tweet.author.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('@${tweet.author.username}',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 6),
                          Text('· ${_relativeTime(tweet.createdAt)}',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isOwnTweet && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onPressed: () => _confirmDelete(context),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(tweet.content, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('${tweet.replyCount}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(width: 24),
              Icon(Icons.repeat, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('${tweet.retweetCount}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: onToggleLike,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      tweet.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: tweet.isLiked ? Colors.red : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tweet.likeCount}',
                      style: TextStyle(color: tweet.isLiked ? Colors.red : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  void _openProfile() {
    Get.to(() => ProfileScreen(username: tweet.author.username));
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tweet?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}