import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(apiClientProvider)),
);

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<({User user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final data = res.asMap;
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await _api.saveTokens(accessToken, refreshToken);

    return (
      user: User.fromJson((data['user'] as Map).cast<String, dynamic>()),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  /// Unlike login, `/auth/me` returns the user as `data` itself rather than
  /// nesting it under `data.user`.
  Future<User> getMe() async {
    final res = await _api.get(ApiEndpoints.me);
    return User.fromJson(res.asMap);
  }

  /// Ends this session only. Omitting the refresh token would sign the user
  /// out of every device.
  Future<void> logout() async {
    try {
      final refreshToken = await _api.readRefreshToken();
      await _api.post(
        ApiEndpoints.logout,
        data: refreshToken == null ? null : {'refreshToken': refreshToken},
      );
    } catch (_) {
      // A failed logout must never strand the user in a signed-in shell —
      // clearing the local tokens below is what actually ends the session.
    }
    await _api.clearTokens();
  }

  /// Revokes every *other* session server-side; this one stays valid.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
