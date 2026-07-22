import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_approval/core/network/api_client.dart';
import 'package:note_approval/core/theme/theme_provider.dart';
import 'package:note_approval/features/auth/data/auth_repository.dart';
import 'package:note_approval/main.dart';
import 'package:note_approval/shared/models/user.dart';

/// Boots with no session and, crucially, WITHOUT touching the network: the real
/// repo's getMe() fires a Dio request whose connect-timeout timer is still
/// pending when the test ends, which flutter_test flags as a failure. Throwing
/// immediately makes AuthNotifier._init land on the unauthenticated state with
/// no timer outstanding.
class _NoNetworkAuthRepo extends AuthRepository {
  _NoNetworkAuthRepo() : super(ApiClient());

  @override
  Future<User> getMe() async => throw Exception('no session in test');
}

void main() {
  testWidgets('Smoke test NFA app boot', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(_NoNetworkAuthRepo()),
        ],
        child: const VistarApp(),
      ),
    );
    await tester.pump(); // let _init resolve to the unauthenticated state

    // Boots without throwing and mounts the app.
    expect(find.byType(VistarApp), findsOneWidget);
  });
}
