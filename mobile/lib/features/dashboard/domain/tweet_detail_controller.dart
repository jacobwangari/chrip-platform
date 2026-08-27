import 'package:get/get.dart';

import '../data/tweet_repository.dart';
import 'tweet_model.dart';

/// One instance per tweet detail screen visited (tagged by tweet id
/// in the screen, same pattern as ProfileController) — never shared
/// across two different threads.
class TweetDetailController extends GetxController {
  final TweetRepository _repository = TweetRepository();
  final int tweetId;

  TweetDetailController({required this.tweetId});

  final Rx<TweetModel?> tweet = Rx<TweetModel?>(null);
  final RxList<TweetModel> replies = <TweetModel>[].obs;

  final RxBool isLoadingTweet = false.obs;
  final RxBool isLoadingReplies = false.obs;
  final RxBool isLoadingMoreReplies = false.obs;
  final RxBool isTogglingLike = false.obs;
  final RxString errorMessage = ''.obs;

  String? _nextRepliesUrl;
  bool get hasMoreReplies => _nextRepliesUrl != null;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadTweet(), loadReplies()]);
  }

  Future<void> loadTweet() async {
    isLoadingTweet.value = true;
    errorMessage.value = '';
    try {
      tweet.value = await _repository.fetchTweetDetail(tweetId);
    } on TweetException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingTweet.value = false;
    }
  }

  Future<void> loadReplies() async {
    isLoadingReplies.value = true;
    try {
      final page = await _repository.fetchReplies(tweetId);
      replies.assignAll(page.tweets);
      _nextRepliesUrl = page.nextUrl;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingReplies.value = false;
    }
  }

  Future<void> fetchMoreReplies() async {
    if (!hasMoreReplies || isLoadingMoreReplies.value) return;

    isLoadingMoreReplies.value = true;
    try {
      final page = await _repository.fetchReplies(tweetId, cursorUrl: _nextRepliesUrl);
      replies.addAll(page.tweets);
      _nextRepliesUrl = page.nextUrl;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingMoreReplies.value = false;
    }
  }

  Future<void> refresh() => loadAll();

  Future<void> toggleLike() async {
    final current = tweet.value;
    if (current == null || isTogglingLike.value) return;

    isTogglingLike.value = true;
    final wasLiked = current.isLiked;

    // Optimistic update — same pattern as TweetController.toggleLike.
    tweet.value = current.copyWith(
      isLiked: !wasLiked,
      likeCount: current.likeCount + (wasLiked ? -1 : 1),
    );

    try {
      tweet.value = wasLiked
          ? await _repository.unlikeTweet(tweetId)
          : await _repository.likeTweet(tweetId);
    } on TweetException catch (e) {
      tweet.value = current; // revert
      errorMessage.value = e.message;
    } finally {
      isTogglingLike.value = false;
    }
  }

  /// [originalTweetId] should be tweet.value's retweetOfId when the
  /// displayed tweet is itself a retweet — resolved by the screen,
  /// same rule as TweetController.retweetTweet's callers.
  Future<bool> retweet(int originalTweetId) async {
    try {
      await _repository.createTweet(content: '', retweetOfId: originalTweetId);
      return true;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
      return false;
    }
  }

  Future<bool> deleteTweet() async {
    try {
      await _repository.deleteTweet(tweetId);
      return true;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
      return false;
    }
  }

  /// Called after a reply posts successfully from this screen —
  /// bumps the visible count immediately and refetches the first
  /// page of replies so the new one appears without a manual refresh.
  Future<void> afterReplyPosted() async {
    final current = tweet.value;
    if (current != null) {
      tweet.value = current.copyWith(replyCount: current.replyCount + 1);
    }
    await loadReplies();
  }
}