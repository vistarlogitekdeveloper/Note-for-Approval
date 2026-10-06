import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/telemetry/telemetry.dart';
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
      // Usage analytics (not awaited): a restored session is a sign-in,
      // before the state change so the first screen is already theirs.
      _identify(user);
      state = AuthState(initializing: false, user: user);
    } catch (_) {
      state = const AuthState(initializing: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(initializing: false, error: null);
    final result = await _repo.login(email: email, password: password);
    // Usage analytics (not awaited): before the state change, so the screen it
    // leads to is already theirs.
    _identify(result.user);
    state = AuthState(initializing: false, user: result.user);
  }

  Future<void> logout() async {
    // Usage analytics: not awaited, sign-out never waits for it.
    Telemetry.signedOut();
    await _repo.logout();
    state = const AuthState(initializing: false);
  }

  /// Called by the API client when a refresh is rejected. The tokens are
  /// already cleared by then, so this only has to reset the UI.
  void handleSessionExpired() {
    if (!mounted) return;
    // An expired session is a sign-out too (not awaited).
    if (state.isAuthenticated) Telemetry.signedOut();
    state = const AuthState(initializing: false);
  }

  /// Usage analytics: who this is (user id and role only). Fire and forget.
  void _identify(User user) =>
      Telemetry.signedIn(userId: user.id, role: user.role.name);

  Future<void> refresh() async {
    try {
      final user = await _repo.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }
}
