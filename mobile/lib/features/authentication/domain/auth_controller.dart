import 'package:get/get.dart';

import '../../../core/network/token_storage.dart';
import '../data/auth_repository.dart';
import 'user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends GetxController {
  final AuthRepository _repository = AuthRepository();

  final Rx<AuthStatus> status = AuthStatus.unknown.obs;
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxString errorMessage = ''.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  /// Called once at app startup to check whether a stored token still
  /// authenticates the user, so they don't have to log in every launch.
  Future<void> checkAuthStatus() async {
    final hasTokens = await TokenStorage.instance.hasTokens;
    if (!hasTokens) {
      status.value = AuthStatus.unauthenticated;
      return;
    }

    try {
      currentUser.value = await _repository.fetchMe();
      status.value = AuthStatus.authenticated;
    } catch (_) {
      status.value = AuthStatus.unauthenticated;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _runAuthAction(() => _repository.register(
          username: username,
          email: email,
          password: password,
          displayName: displayName,
        ));
  }

  Future<bool> login({required String username, required String password}) async {
    return _runAuthAction(() => _repository.login(username: username, password: password));
  }

  Future<bool> _runAuthAction(Future<UserModel> Function() action) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      currentUser.value = await action();
      status.value = AuthStatus.authenticated;
      return true;
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      status.value = AuthStatus.unauthenticated;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    currentUser.value = null;
    status.value = AuthStatus.unauthenticated;
  }

  /// Clears any leftover error from a previous form/attempt. Called
  /// whenever a screen using this shared error state is entered, so
  /// a login failure doesn't "leak" into the register screen (or vice
  /// versa) since AuthController is a single app-wide instance.
  void clearError() {
    errorMessage.value = '';
  }

  /// Wired to DioClient.onAuthExpired so a failed refresh (e.g. expired
  /// or blacklisted refresh token) forces the UI back to the login screen.
  void handleForcedLogout() {
    currentUser.value = null;
    status.value = AuthStatus.unauthenticated;
  }
}