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
import '../../features/admin/screens/admin_screen.dart';
import '../../features/admin/screens/users_screen.dart';
import '../../features/admin/screens/hierarchy_screen.dart';
import '../../features/admin/screens/masters_screen.dart';
import '../../features/admin/screens/smtp_settings_screen.dart';
import '../../features/admin/screens/audit_screen.dart';
import '../../features/shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Handle loading splash/initializing state
      if (auth.initializing) {
        return loc == '/splash' ? null : '/splash';
      }

      final isAuthed = auth.isAuthenticated;

      if (loc == '/splash') {
        return isAuthed ? '/dashboard' : '/login';
      }

      final isPublic = loc == '/login';
      if (!isAuthed && !isPublic) return '/login';
      if (isAuthed && loc == '/login') return '/dashboard';

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
          body: Center(
            child: CircularProgressIndicator(),
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
                path: 'hierarchy',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const HierarchyScreen(),
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
                path: 'smtp',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const SmtpSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'audit',
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const AuditScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

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
