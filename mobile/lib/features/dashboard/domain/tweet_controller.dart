import 'package:get/get.dart';

import '../data/tweet_repository.dart';
import 'tweet_model.dart';

class TweetController extends GetxController {
  final TweetRepository _repository = TweetRepository();

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
      final page = await _repository.fetchTweets();
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

  Future<bool> postTweet(String content) async {
    if (content.trim().isEmpty) return false;

    isPosting.value = true;
    errorMessage.value = '';
    try {
      final tweet = await _repository.createTweet(content: content.trim());
      tweets.insert(0, tweet);
      return true;
    } on TweetException catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isPosting.value = false;
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
}
