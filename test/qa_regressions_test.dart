import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:note_approval/core/network/api_client.dart';
import 'package:note_approval/core/network/api_exception.dart';
import 'package:note_approval/core/router/app_router.dart';
import 'package:note_approval/core/theme/theme_provider.dart';
import 'package:note_approval/features/auth/data/auth_repository.dart';
import 'package:note_approval/features/notes/data/notes_repository.dart';
import 'package:note_approval/features/notes/models/note.dart';
import 'package:note_approval/main.dart';
import 'package:note_approval/shared/models/user.dart';

/// Regressions found in the full QA pass of the web app. Each test drives the
/// real app — router, shell and screens — with the network replaced by fakes.

const _me = User(id: 'u-riya', name: 'Riya Initiator', email: 'riya@example.com', role: UserRole.user);

class _FakeAuth extends AuthRepository {
  _FakeAuth({this.session = false, this.loginError, this.me}) : super(ApiClient());

  final bool session;
  final ApiException? loginError;

  /// Completes when the test says the session check is done; none = at once.
  final Completer<User>? me;

  @override
  Future<bool> hasStoredSession() async => session;

  @override
  Future<User> getMe() => me?.future ?? Future.value(_me);

  @override
  Future<({User user, String accessToken, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return (user: _me, accessToken: 'a', refreshToken: 'r');
  }
}

Map<String, dynamic> _noteJson(int i, {String status = 'pendingApproval'}) => {
      'id': 'n$i',
      'note_number': 'NFA-2026-${i.toString().padLeft(4, '0')}',
      'purpose_id': 'p1',
      'purpose': {'id': 'p1', 'name': 'Transport payment approval for the Waluj plant'},
      'objective_in_detail': 'Approve the transport payments for the pick-ups listed in the brief note',
      'brief_note': 'Rates:\nWALUJ To MYSORE PICK UP\t19500\t18000',
      'benefit': 'On-time dispatch',
      'cost_impact': '207800',
      'status': status,
      'current_level': 1,
      'total_levels': 3,
      'revision': 1,
      'initiator_id': 'u-riya',
      'initiator': {'id': 'u-riya', 'name': 'Riya Initiator With A Very Long Name', 'email': 'riya@example.com'},
      'created_at': '2026-10-14T05:00:00.000Z',
      'updated_at': '2026-10-14T05:00:00.000Z',
      'approverChain': [],
      'approvalTrail': [],
      'attachments': [],
    };

class _FakeNotes extends NotesRepository {
  _FakeNotes() : super(ApiClient());

  final notes = [for (var i = 1; i <= 4; i++) Note.fromJson(_noteJson(i, status: i == 1 ? 'draft' : 'pendingApproval'))];

  @override
  Future<NotePage> getNotes({bool mine = false, String? status, String? search, int page = 1, int limit = 100}) async =>
      NotePage(notes: notes, page: 1, limit: 100, total: 250, pages: 3);

  @override
  Future<List<Note>> getMyNotes({String? status}) async => notes;

  @override
  Future<List<Note>> getRecentNotes() async => notes;

  @override
  Future<List<Note>> getPendingApprovals() async => notes.skip(1).toList();

  @override
  Future<MyDecisionPage> getMyDecisions({String? action}) async =>
      const MyDecisionPage(decisions: [], approved: 3, rejected: 1, reassigned: 2, total: 6);

  @override
  Future<DashboardStats> getDashboardStats() async => const DashboardStats(
        all: StatusCounts(total: 9, draft: 1, pending: 3, approved: 2, rejected: 1, returned: 2),
        mine: StatusCounts(total: 9, draft: 1, pending: 3, approved: 2, rejected: 1, returned: 2),
        pendingMyAction: 3,
      );

  @override
  Future<Note> getNoteById(String id) async => notes.firstWhere((n) => n.id == id);

  @override
  Future<List<PurposeMaster>> getPurposes({bool includeInactive = false}) async =>
      const [PurposeMaster(id: 'p1', name: 'Transport payment approval for the Waluj plant')];

  @override
  Future<List<User>> getSelectableApprovers() async => const [];
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required AuthRepository auth,
  Size size = const Size(1366, 768),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authRepositoryProvider.overrideWithValue(auth),
    notesRepositoryProvider.overrideWithValue(_FakeNotes()),
  ]);
  _containers.add(container);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VistarApp()));
  await _settle(tester);
  return container;
}

/// Shimmers and the splash loader animate forever, so pumpAndSettle would
/// never return; a few fixed frames are enough for futures to land.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

final _containers = <ProviderContainer>[];

/// Unmount and dispose before the test ends so timers (the header's
/// one-minute pending-count refresh) are cancelled.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (final c in _containers) {
    c.dispose();
  }
  _containers.clear();
  await tester.pump(const Duration(seconds: 2));
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('sign-in', () {
    Future<void> attempt(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'riya@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
      await tester.tap(find.text('Sign in').last);
      await _settle(tester);
    }

    testWidgets('a wrong password keeps the form and says why', (tester) async {
      await _pumpApp(tester,
          auth: _FakeAuth(
            loginError: const ApiException(message: 'Invalid', statusCode: 401, code: 'INVALID_CREDENTIALS'),
          ));
      await attempt(tester);
      // Before the fix the router was rebuilt on every auth change: the form
      // emptied and the error never showed.
      expect(find.text('Invalid email or password. Please try again.'), findsOneWidget);
      expect(find.text('riya@example.com'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('rate limiting and a deactivated account get their own message', (tester) async {
      await _pumpApp(tester, auth: _FakeAuth(loginError: const ApiException(message: 'slow down', statusCode: 429)));
      await attempt(tester);
      expect(find.textContaining('Too many sign-in attempts'), findsOneWidget);
      await _unmount(tester);

      await _pumpApp(tester,
          auth: _FakeAuth(
            loginError: const ApiException(
                message: 'This account is deactivated. Contact an administrator.', statusCode: 403),
          ));
      await attempt(tester);
      expect(find.text('This account is deactivated. Contact an administrator.'), findsOneWidget);
      await _unmount(tester);
    });
  });

  testWidgets('a page opened while the session is restoring is where you land', (tester) async {
    final me = Completer<User>();
    final c = await _pumpApp(tester, auth: _FakeAuth(session: true, me: me));
    c.read(routerProvider).go('/approvals/mine');
    await _settle(tester);
    expect(_location(c), startsWith('/splash'));
    me.complete(_me);
    await _settle(tester);
    // It used to be the dashboard, whatever was asked for.
    expect(_location(c), '/approvals/mine');
    await _unmount(tester);
  });

  const pages = ['/dashboard', '/notes', '/notes/new', '/notes/n2', '/approvals', '/approvals/mine'];

  for (final size in const [Size(1366, 768), Size(800, 1000)]) {
    group('${size.width.toInt()} x ${size.height.toInt()}', () {
      for (final path in pages) {
        testWidgets('$path lays out without overflowing', (tester) async {
          final c = await _pumpApp(tester, auth: _FakeAuth(session: true), size: size);
          c.read(routerProvider).go(path);
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '$path threw at $size');
          await _unmount(tester);
        });
      }
    });
  }

  group('phone width (375 x 812)', () {
    const phone = Size(375, 812);

    for (final path in pages) {
      testWidgets('$path lays out without overflowing', (tester) async {
        final c = await _pumpApp(tester, auth: _FakeAuth(session: true), size: phone);
        c.read(routerProvider).go(path);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '$path threw (overflow?) at 375px');
        await _unmount(tester);
      });
    }

    testWidgets('the menu button opens the navigation drawer', (tester) async {
      await _pumpApp(tester, auth: _FakeAuth(session: true), size: phone);
      await tester.tap(find.byTooltip('Menu'));
      await _settle(tester);
      // It threw "Scaffold.of() called with a context that does not contain a
      // Scaffold" and nothing opened.
      expect(tester.takeException(), isNull);
      expect(find.text('Pending Approvals'), findsWidgets);
      expect(find.text('My Decisions'), findsWidgets);
      await _unmount(tester);
    });
  });

  testWidgets('My Notes says when it is showing only part of the list', (tester) async {
    final c = await _pumpApp(tester, auth: _FakeAuth(session: true));
    c.read(routerProvider).go('/notes');
    await _settle(tester);
    expect(find.textContaining('Showing the latest 4 of 250 notes'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('the header bell shows the real pending count', (tester) async {
    await _pumpApp(tester, auth: _FakeAuth(session: true));
    expect(find.byTooltip('3 notes waiting for your decision'), findsOneWidget);
    await _unmount(tester);
  });
}
