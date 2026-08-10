import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../shared/widgets/tweet_card.dart';
import '../../authentication/domain/auth_controller.dart';
import '../domain/tweet_controller.dart';
import 'compose_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = Get.find<AuthController>();
  final _tweets = Get.put(TweetController());
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final nearBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300;
      if (nearBottom) _tweets.fetchMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chirp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.logout(),
          ),
        ],
      ),
      body: Obx(() {
        if (_tweets.isLoading.value && _tweets.tweets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_tweets.tweets.isEmpty) {
          return const Center(child: Text('No tweets yet — be the first to post.'));
        }

        return RefreshIndicator(
          onRefresh: _tweets.refresh,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _tweets.tweets.length + (_tweets.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _tweets.tweets.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final tweet = _tweets.tweets[index];
              final isOwnTweet = tweet.author.id == _auth.currentUser.value?.id;

              return TweetCard(
                tweet: tweet,
                isOwnTweet: isOwnTweet,
                onDelete: isOwnTweet ? () => _tweets.deleteTweet(tweet.id) : null,
                onToggleLike: () => _tweets.toggleLike(tweet.id),
                // If this card is already a retweet, retweeting again
                // must target the original (retweetOfId), never the
                // retweet row itself — the backend rejects retweeting
                // a retweet.
                onRetweet: () => _tweets.retweetTweet(tweet.retweetOfId ?? tweet.id),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const ComposeScreen()),
        child: const Icon(Icons.add),
      ),
    );
  }
}