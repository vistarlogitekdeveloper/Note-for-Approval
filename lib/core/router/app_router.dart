import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/notes/screens/my_notes_screen.dart';
import '../../features/notes/screens/create_note_screen.dart';
import '../../features/notes/screens/note_detail_screen.dart';
import '../../features/approvals/screens/pending_approvals_screen.dart';
import '../../features/approvals/screens/my_decisions_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/admin/screens/masters_screen.dart';
import '../../features/admin/screens/audit_screen.dart';
import '../../features/admin/screens/smtp_settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../shared/widgets/vistar_brand.dart';
import '../telemetry/telemetry.dart';

/// Where to go once the splash or the sign-in is out of the way: the page the
/// user asked for (a reload, a bookmarked or e-mailed note link), carried in
/// `?from=`. Only an in-app path is accepted.
String _landing(GoRouterState state) {
  final from = state.uri.queryParameters['from'];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/dashboard';
  }
  if (from.startsWith('/login') || from.startsWith('/splash')) return '/dashboard';
  return from;
}

/// [loc] with its query, ready to be carried in `?from=`.
String _withFrom(String target, GoRouterState state) {
  final here = state.uri.toString();
  if (here == '/' || here.startsWith('/login') || here.startsWith('/splash')) {
    return target;
  }
  return Uri(path: target, queryParameters: {'from': here}).toString();
}

final routerProvider = Provider<GoRouter>((ref) {
  // Read, never watch: the router must be built once. Rebuilding it on every
  // auth change threw away the navigation stack and every open screen's state
  // — a failed sign-in cleared the form and its error message, and signing in
  // always landed on the dashboard. Auth changes reach the redirect through
  // refreshListenable instead.
  final router = GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      // Handle loading splash/initializing state
      if (auth.initializing) {
        return loc == '/splash' ? null : _withFrom('/splash', state);
      }

      final isAuthed = auth.isAuthenticated;

      if (loc == '/splash') {
        if (!isAuthed) {
          final from = state.uri.queryParameters['from'];
          return from == null
              ? '/login'
              : Uri(path: '/login', queryParameters: {'from': from}).toString();
        }
        return _landing(state);
      }

      final isPublic = loc == '/login';
      if (!isAuthed && !isPublic) return _withFrom('/login', state);
      if (isAuthed && loc == '/login') return _landing(state);

      // Role-based route guards
      final user = auth.user;
      final role = user?.role;
      if (user != null && role != null) {
        if (loc.startsWith('/admin') && !role.canAdmin) return '/dashboard';
        if (loc.startsWith('/approvals') && !role.canApprove) return '/dashboard';
      }

      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          backgroundColor: Colors.transparent,
          // The orbit loader is the app's first impression, and it is what
          // the session-restore wait is spent on — a bare spinner wasted it.
          body: AmbientBackground(
            showWatermark: false,
            child: Center(child: SplashOrbitLoader()),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/notes',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MyNotesScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CreateNoteScreen(),
                ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: NoteDetailScreen(id: state.pathParameters['id']!),
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: CreateNoteScreen(
                        editId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/approvals',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PendingApprovalsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'mine',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const MyDecisionsScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const AdminScreen(),
            ),
            routes: [
              GoRoute(
                path: 'users',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const UsersAdminScreen(),
                ),
              ),
              GoRoute(
                path: 'masters',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const MastersScreen(),
                ),
              ),
              GoRoute(
                path: 'audit',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const AuditScreen(),
                ),
              ),
              GoRoute(
                path: 'smtp',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SmtpSettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return _withScreenViews(ref, router);
});

/// Reports each screen the router shows to usage analytics (by route
/// pattern; see Telemetry.screen).
GoRouter _withScreenViews(Ref ref, GoRouter router) {
  if (!Telemetry.enabled) return router;
  // The delegate, not the route-information provider: it also hears the
  // location changes a redirect makes (sign-in landing on the dashboard).
  void report() {
    try {
      Telemetry.screen(
          router.routerDelegate.currentConfiguration.uri.toString());
    } catch (_) {
      // No configuration yet; the next change reports.
    }
  }

  router.routerDelegate.addListener(report);
  ref.onDispose(() => router.routerDelegate.removeListener(report));
  // The listener only hears changes: report the starting screen too.
  WidgetsBinding.instance.addPostFrameCallback((_) => report());
  return router;
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authProvider, (prev, next) {
      if (prev?.isAuthenticated != next.isAuthenticated ||
          prev?.initializing != next.initializing) {
        notifyListeners();
      }
    });
  }
  final Ref _ref;
}
