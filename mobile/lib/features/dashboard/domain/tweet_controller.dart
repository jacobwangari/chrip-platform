import 'package:get/get.dart';

import '../data/tweet_repository.dart';
import 'tweet_model.dart';

class TweetController extends GetxController {
  final TweetRepository _repository = TweetRepository();

  /// Which feed this instance serves — '/tweets/' (following) or
  /// '/tweets/discover/' (unfiltered). Two separate TweetController
  /// instances (tagged 'following' and 'discover') each own their
  /// own list, pagination cursor, and loading state — they never
  /// share state, so switching tabs never mixes the two feeds.
  final String feedEndpoint;

  TweetController({this.feedEndpoint = '/tweets/'});

  final RxList<TweetModel> tweets = <TweetModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isPosting = false.obs;
  final RxString errorMessage = ''.obs;

  String? _nextUrl;
  bool get hasMore => _nextUrl != null;

  @override
  void onInit() {
    super.onInit();
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final page = await _repository.fetchTweets(endpoint: feedEndpoint);
      tweets.assignAll(page.tweets);
      _nextUrl = page.nextUrl;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Pull-to-refresh — reloads from the top without disturbing the
  /// loading-more state, since these are separate UI affordances.
  Future<void> refresh() => fetchInitial();

  Future<void> fetchMore() async {
    if (!hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      final page = await _repository.fetchTweets(cursorUrl: _nextUrl);
      tweets.addAll(page.tweets);
      _nextUrl = page.nextUrl;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<bool> postTweet(String content, {List<Map<String, String>>? media}) async {
    if (content.trim().isEmpty && (media == null || media.isEmpty)) return false;

    isPosting.value = true;
    errorMessage.value = '';
    try {
      final tweet = await _repository.createTweet(content: content.trim(), media: media);
      tweets.insert(0, tweet);
      return true;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isPosting.value = false;
    }
  }

  /// [originalTweetId] must point to a true original, never another
  /// retweet — the backend enforces this and rejects otherwise, so
  /// callers should pass tweet.retweetOfId when re-sharing something
  /// that's already a retweet.
  Future<bool> retweetTweet(int originalTweetId) async {
    errorMessage.value = '';
    try {
      final tweet = await _repository.createTweet(content: '', retweetOfId: originalTweetId);
      tweets.insert(0, tweet);
      return true;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
      return false;
    }
  }

  Future<void> deleteTweet(int id) async {
    // Optimistic removal — revert if the server call fails.
    final index = tweets.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removed = tweets[index];
    tweets.removeAt(index);

    try {
      await _repository.deleteTweet(id);
    } on TweetException catch (e) {
      tweets.insert(index, removed);
      errorMessage.value = e.message;
    }
  }

  Future<void> toggleLike(int tweetId) async {
    final index = tweets.indexWhere((t) => t.id == tweetId);
    if (index == -1) return;

    final current = tweets[index];
    final wasLiked = current.isLiked;

    // Optimistic update — flip immediately, revert on failure.
    tweets[index] = current.copyWith(
      isLiked: !wasLiked,
      likeCount: current.likeCount + (wasLiked ? -1 : 1),
    );

    try {
      final updated =
          wasLiked ? await _repository.unlikeTweet(tweetId) : await _repository.likeTweet(tweetId);

      // Guard against the list having changed (e.g. tweet deleted, or
      // a refresh happened) while the request was in flight.
      final currentIndex = tweets.indexWhere((t) => t.id == tweetId);
      if (currentIndex != -1) {
        tweets[currentIndex] = updated;
      }
    } on TweetException catch (e) {
      final currentIndex = tweets.indexWhere((t) => t.id == tweetId);
      if (currentIndex != -1) {
        tweets[currentIndex] = current; // revert to pre-toggle state
      }
      errorMessage.value = e.message;
    }
  }
}