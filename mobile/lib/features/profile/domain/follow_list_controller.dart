import 'package:get/get.dart';

import '../../authentication/domain/user_model.dart';
import '../data/user_repository.dart';

enum FollowListMode { followers, following }

/// One instance per screen visited (tagged by username+mode in the
/// screen), so viewing followers for two different users never mixes
/// their lists.
class FollowListController extends GetxController {
  final UserRepository _repository = UserRepository();
  final String username;
  final FollowListMode mode;

  FollowListController({required this.username, required this.mode});

  final RxList<UserModel> users = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
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
      final page = mode == FollowListMode.followers
          ? await _repository.fetchFollowers(username)
          : await _repository.fetchFollowing(username);
      users.assignAll(page.users);
      _nextUrl = page.nextUrl;
    } on UserException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() => fetchInitial();

  Future<void> fetchMore() async {
    if (!hasMore || isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      final page = mode == FollowListMode.followers
          ? await _repository.fetchFollowers(username, cursorUrl: _nextUrl)
          : await _repository.fetchFollowing(username, cursorUrl: _nextUrl);
      users.addAll(page.users);
      _nextUrl = page.nextUrl;
    } on UserException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }
}