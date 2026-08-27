import 'dart:async';

import 'package:get/get.dart';

import '../../authentication/domain/user_model.dart';
import '../../profile/data/user_repository.dart';

/// Reuses UserRepository from the profile feature rather than
/// duplicating it — search results and profile views are the same
/// underlying resource (UserModel), just a different entry point.
class SearchController extends GetxController {
  final UserRepository _repository = UserRepository();

  final RxString query = ''.obs;
  final RxList<UserModel> results = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Timer? _debounce;
  static const _debounceDuration = Duration(milliseconds: 400);

  /// Called on every keystroke — debounced so a query isn't fired for
  /// every character typed, only once typing pauses.
  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      results.clear();
      isLoading.value = false;
      return;
    }

    _debounce = Timer(_debounceDuration, () => _search(value.trim()));
  }

  Future<void> _search(String value) async {
    // A later keystroke's debounce may have already fired before this
    // completes — guard against an in-flight, now-stale query
    // overwriting results for the current (different) query text.
    final requestedQuery = value;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final found = await _repository.searchUsers(value);
      if (query.value.trim() == requestedQuery) {
        results.assignAll(found);
      }
    } on UserException catch (e) {
      if (query.value.trim() == requestedQuery) {
        errorMessage.value = e.message;
      }
    } finally {
      if (query.value.trim() == requestedQuery) {
        isLoading.value = false;
      }
    }
  }

  Future<void> toggleFollow(UserModel user) async {
    final index = results.indexWhere((u) => u.id == user.id);
    if (index == -1) return;

    final wasFollowing = user.isFollowing;

    // Optimistic update — same pattern as ProfileController.toggleFollow.
    results[index] = user.copyWith(
      isFollowing: !wasFollowing,
      followerCount: user.followerCount + (wasFollowing ? -1 : 1),
    );

    try {
      final updated =
          wasFollowing ? await _repository.unfollow(user.username) : await _repository.follow(user.username);
      final currentIndex = results.indexWhere((u) => u.id == user.id);
      if (currentIndex != -1) {
        results[currentIndex] = updated;
      }
    } on UserException catch (e) {
      final currentIndex = results.indexWhere((u) => u.id == user.id);
      if (currentIndex != -1) {
        results[currentIndex] = user; // revert
      }
      errorMessage.value = e.message;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}