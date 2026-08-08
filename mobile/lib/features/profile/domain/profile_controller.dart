import 'package:get/get.dart';

import '../../authentication/domain/user_model.dart';
import '../data/user_repository.dart';

/// Scoped per profile screen (created with a tag, not a global
/// singleton like AuthController) — each profile visited gets its own
/// controller instance so viewing two profiles never mixes their state.
class ProfileController extends GetxController {
  final UserRepository _repository = UserRepository();
  final String username;

  ProfileController({required this.username});

  final Rx<UserModel?> user = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool isTogglingFollow = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      user.value = await _repository.fetchUser(username);
    } on UserException catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleFollow() async {
    final current = user.value;
    if (current == null || isTogglingFollow.value) return;

    isTogglingFollow.value = true;

    // Optimistic update — flip immediately, revert on failure.
    final wasFollowing = current.isFollowing;
    user.value = current.copyWith(
      isFollowing: !wasFollowing,
      followerCount: current.followerCount + (wasFollowing ? -1 : 1),
    );

    try {
      final updated = wasFollowing
          ? await _repository.unfollow(username)
          : await _repository.follow(username);
      user.value = updated;
    } on UserException catch (e) {
      user.value = current; // revert
      errorMessage.value = e.message;
    } finally {
      isTogglingFollow.value = false;
    }
  }
}