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
  final VoidCallback? onRetweet;
  final VoidCallback? onReply;
  final VoidCallback? onOpenDetail;

  const TweetCard({
    super.key,
    required this.tweet,
    this.isOwnTweet = false,
    this.onDelete,
    this.onToggleLike,
    this.onRetweet,
    this.onReply,
    this.onOpenDetail,
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
    // For a retweet, the card displays the ORIGINAL tweet's author,
    // content, and timestamp — the retweet row itself has no content
    // of its own. Engagement counts (like/reply/retweet) shown below
    // are still the retweet's own — see docs/Decisions.md.
    final displayAuthor = tweet.isRetweet ? tweet.originalAuthor! : tweet.author;
    final displayContent = tweet.isRetweet ? (tweet.originalContent ?? '') : tweet.content;
    final displayTime = tweet.isRetweet ? tweet.originalCreatedAt! : tweet.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tweet.isRetweet)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 32),
              child: Row(
                children: [
                  Icon(Icons.repeat, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    '${tweet.author.displayName} reposted',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(displayAuthor.username),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: displayAuthor.avatarUrl != null
                      ? NetworkImage(displayAuthor.avatarUrl!)
                      : null,
                  child: displayAuthor.avatarUrl == null
                      ? Text(displayAuthor.displayName.isNotEmpty
                          ? displayAuthor.displayName[0].toUpperCase()
                          : '?')
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfile(displayAuthor.username),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(displayAuthor.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('@${displayAuthor.username}',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 6),
                          Text('· ${_relativeTime(displayTime)}',
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
          GestureDetector(
            onTap: onOpenDetail,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayContent, style: const TextStyle(fontSize: 15)),
                if (tweet.media.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      tweet.media.first.url,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey.shade300,
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onReply,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${tweet.replyCount}', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: onRetweet,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(Icons.repeat, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${tweet.retweetCount}', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
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

  void _openProfile(String username) {
    Get.to(() => ProfileScreen(username: username));
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