import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/tweet_card.dart';
import '../../authentication/domain/auth_controller.dart';
import '../../notifications/domain/notification_controller.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/tweet_controller.dart';
import 'compose_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _notifications = Get.find<NotificationController>();
  late final TabController _tabController;

  // Two independent controllers, tagged so they never share state —
  // switching tabs never mixes the following feed with the discover
  // feed, and each keeps its own scroll position and pagination cursor.
  late final TweetController _followingController;
  late final TweetController _discoverController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _followingController =
        Get.put(TweetController(feedEndpoint: '/tweets/'), tag: 'following');
    _discoverController =
        Get.put(TweetController(feedEndpoint: '/tweets/discover/'), tag: 'discover');

    // Real trigger for populating notifications — see NotificationController
    // for why onInit alone doesn't fetch at cold start.
    _notifications.fetchInitial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Tagged controllers aren't auto-disposed with the route the way
    // Get.put without a tag sometimes is — remove them explicitly so
    // leaving the dashboard doesn't leak two feed controllers.
    Get.delete<TweetController>(tag: 'following');
    Get.delete<TweetController>(tag: 'discover');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chirp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              final username = _auth.currentUser.value?.username;
              if (username != null) {
                Get.to(() => ProfileScreen(username: username));
              }
            },
          ),
          Obx(() => Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => Get.to(() => const NotificationsScreen()),
                  ),
                  if (_notifications.unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          _notifications.unreadCount > 9 ? '9+' : '${_notifications.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              )),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedList(controller: _followingController, currentUserId: _auth.currentUser.value?.id),
          _FeedList(controller: _discoverController, currentUserId: _auth.currentUser.value?.id),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const ComposeScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Extracted so the two tabs render identically without duplicating
/// the scroll/pagination/empty-state logic — the only thing that
/// differs between tabs is which TweetController feeds it.
class _FeedList extends StatefulWidget {
  final TweetController controller;
  final int? currentUserId;

  const _FeedList({required this.controller, required this.currentUserId});

  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // preserves scroll position when switching tabs

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final nearBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300;
      if (nearBottom) widget.controller.fetchMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;

    return Obx(() {
      if (controller.isLoading.value && controller.tweets.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.tweets.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              controller.feedEndpoint == '/tweets/'
                  ? "No tweets yet — follow someone, or post your first chirp."
                  : "No tweets yet — be the first to post.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: controller.tweets.length + (controller.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= controller.tweets.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final tweet = controller.tweets[index];
            final isOwnTweet = tweet.author.id == widget.currentUserId;

            return TweetCard(
              tweet: tweet,
              isOwnTweet: isOwnTweet,
              onDelete: isOwnTweet ? () => controller.deleteTweet(tweet.id) : null,
              onToggleLike: () => controller.toggleLike(tweet.id),
              onRetweet: () => controller.retweetTweet(tweet.retweetOfId ?? tweet.id),
              onReply: () {
                // Reply to the ORIGINAL tweet for a retweet card (there's
                // nothing meaningful to reply to on the empty retweet
                // wrapper itself), matching how retweetTweet already
                // targets tweet.retweetOfId in the same situation.
                final targetId = tweet.isRetweet ? tweet.retweetOfId! : tweet.id;
                final targetUsername = tweet.isRetweet ? tweet.originalAuthor!.username : tweet.author.username;

                Get.to(() => ComposeScreen(
                      parentId: targetId,
                      replyingToUsername: targetUsername,
                      onPosted: () => controller.bumpReplyCount(targetId),
                    ));
              },
            );
          },
        ),
      );
    });
  }
}