import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../domain/tweet_model.dart';

class TweetException implements Exception {
  final String message;
  TweetException(this.message);
  @override
  String toString() => message;
}

/// A page of tweets plus the cursor URL for the next page, if any.
/// DRF's CursorPagination returns `next` as a full absolute URL —
/// we pass it straight back to Dio rather than re-deriving query params.
class TweetPage {
  final List<TweetModel> tweets;
  final String? nextUrl;

  TweetPage({required this.tweets, required this.nextUrl});
}

class TweetRepository {
  final Dio _dio = DioClient().dio;

  /// Fetches the first page when [cursorUrl] is null, or the page at
  /// that cursor otherwise. Dio treats an absolute URL as an override
  /// of baseUrl, so passing the raw `next` link straight back in works.
  /// [endpoint] selects which feed — '/tweets/' (following) or
  /// '/tweets/discover/' (unfiltered) — ignored once cursorUrl is set,
  /// since the cursor URL already encodes the full path.
  Future<TweetPage> fetchTweets({String? cursorUrl, String endpoint = '/tweets/'}) async {
    try {
      final response = cursorUrl != null
          ? await _dio.get(cursorUrl)
          : await _dio.get(endpoint);

      final results = (response.data['results'] as List)
          .map((json) => TweetModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return TweetPage(tweets: results, nextUrl: response.data['next'] as String?);
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  Future<TweetModel> createTweet({
    required String content,
    int? parentId,
    int? retweetOfId,
    List<Map<String, String>>? media,
  }) async {
    try {
      final response = await _dio.post('/tweets/', data: {
        'content': content,
        if (parentId != null) 'parent': parentId,
        if (retweetOfId != null) 'retweet_of': retweetOfId,
        if (media != null && media.isNotEmpty) 'media': media,
      });
      return TweetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  Future<void> deleteTweet(int id) async {
    try {
      await _dio.delete('/tweets/$id/');
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  Future<TweetModel> likeTweet(int id) async {
    try {
      final response = await _dio.post('/tweets/$id/like/');
      return TweetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  Future<TweetModel> unlikeTweet(int id) async {
    try {
      final response = await _dio.delete('/tweets/$id/like/');
      return TweetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  Future<List<TweetModel>> fetchReplies(int tweetId) async {
    try {
      final response = await _dio.get('/tweets/$tweetId/replies/');
      return (response.data['results'] as List)
          .map((json) => TweetModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw TweetException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data.isNotEmpty) {
      final firstKey = data.keys.first;
      final firstValue = data[firstKey];
      if (firstValue is List && firstValue.isNotEmpty) {
        return firstValue.first.toString();
      }
      return firstValue.toString();
    }
    return 'Something went wrong. Please try again.';
  }
}