import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/user.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool initializing;
  final User? user;
  final String? error;

  const AuthState({
    this.initializing = true,
    this.user,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({bool? initializing, User? user, String? error}) =>
      AuthState(
        initializing: initializing ?? this.initializing,
        user: user ?? this.user,
        error: error,
      );

  AuthState get unauthenticated => const AuthState(initializing: false);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider));
  // Refresh tokens are single-use and rotate on every call. Once one is
  // rejected the session cannot be recovered, so drop to the login screen
  // rather than leave a signed-in shell that 401s on every tap.
  ref.read(apiClientProvider).onSessionExpired = notifier.handleSessionExpired;
  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    try {
      final user = await _repo.getMe();
      state = AuthState(initializing: false, user: user);
    } catch (_) {
      state = const AuthState(initializing: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(initializing: false, error: null);
    final result = await _repo.login(email: email, password: password);
    state = AuthState(initializing: false, user: result.user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(initializing: false);
  }

  /// Called by the API client when a refresh is rejected. The tokens are
  /// already cleared by then, so this only has to reset the UI.
  void handleSessionExpired() {
    if (!mounted) return;
    state = const AuthState(initializing: false);
  }

  Future<void> refresh() async {
    try {
      final user = await _repo.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }
}
