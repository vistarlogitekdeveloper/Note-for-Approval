import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/notes/providers/notes_provider.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/vistar_brand.dart';
import 'account_dialogs.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;

  /// The shell's own Scaffold. `Scaffold.of(context)` with this State's
  /// context looks ABOVE the Scaffold built here, so on phones the menu button
  /// threw and the drawer never opened.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 768;

    return Scaffold(
      key: _scaffoldKey,
      // Transparent so the ambient aurora + watermark below shows through;
      // AmbientBackground paints the base colour itself.
      backgroundColor: Colors.transparent,
      drawer: isMobile ? _buildSidebar(user, isMobile: true) : null,
      body: AmbientBackground(
        child: Row(
        children: [
          if (!isMobile)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              width: _sidebarCollapsed ? 68 : 248,
              child: _buildSidebar(user),
            ),
          Expanded(
            child: Column(
              children: [
                _Topbar(
                  user: user,
                  compact: isMobile,
                  onMenuTap: isMobile
                      ? () => _scaffoldKey.currentState?.openDrawer()
                      : () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  collapsed: _sidebarCollapsed,
                ),
                Expanded(
                  child: ClipRect(child: widget.child),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSidebar(User? user, {bool isMobile = false}) {
    final collapsed = _sidebarCollapsed && !isMobile;
    final role = user?.role;

    return Container(
      color: context.c.bg2,
      child: Column(
        children: [
          // Brand row
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 18),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.c.line)),
            ),
            child: Row(
              children: [
                _SidebarLogo(small: collapsed),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appShortName,
                          style: GoogleFonts.bricolageGrotesque(
                            color: context.c.txt,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppStrings.company,
                          style: TextStyle(
                            color: context.c.txt3,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _navGroup('Main', [
                    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', path: '/dashboard', collapsed: collapsed),
                    _NavItem(icon: Icons.description_outlined, label: 'My Notes', path: '/notes', collapsed: collapsed),
                    if (role?.canApprove ?? false) ...[
                      _NavItem(icon: Icons.pending_actions_outlined, label: 'Pending Approvals', path: '/approvals', collapsed: collapsed, exact: true),
                      // An approver who raises no notes of their own has no
                      // other record of their work: My Notes is initiator-only
                      // and the audit log is admin-only.
                      _NavItem(icon: Icons.history_rounded, label: 'My Decisions', path: '/approvals/mine', collapsed: collapsed),
                    ],
                  ], collapsed: collapsed),
                  if (role?.canAdmin ?? false) ...[
                    _navGroup('Administration', [
                      _NavItem(icon: Icons.people_outlined, label: 'Users', path: '/admin/users', collapsed: collapsed),
                      _NavItem(icon: Icons.list_alt_outlined, label: 'Masters', path: '/admin/masters', collapsed: collapsed),
                      _NavItem(icon: Icons.history_outlined, label: 'Audit Log', path: '/admin/audit', collapsed: collapsed),
                      _NavItem(icon: Icons.outgoing_mail, label: 'Email Settings', path: '/admin/smtp', collapsed: collapsed),
                    ], collapsed: collapsed),
                  ],
                ],
              ),
            ),
          ),

          // User block
          Container(
            padding: EdgeInsets.all(collapsed ? 8 : 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.c.line)),
            ),
            child: collapsed
                ? _UserAvatar(user: user, small: true)
                : Row(
                    children: [
                      _UserAvatar(user: user),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'User',
                              style: TextStyle(
                                color: context.c.txt,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.role.label ?? '',
                              style: TextStyle(
                                color: context.c.txt3,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _navGroup(String label, List<Widget> items, {required bool collapsed}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: context.c.txt3,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ...items,
        const SizedBox(height: 4),
      ],
    );
  }
}

class _NavItem extends ConsumerWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.collapsed,
    this.exact = false,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool collapsed;

  /// Set when another nav item lives under this one's path, so this item stays
  /// unlit while that child is open.
  final bool exact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    // Prefix matching keeps a parent lit while you are in its detail views
    // (/notes/:id still belongs to My Notes). It must be opt-out, though: when
    // a nav item sits UNDER another one — /approvals/mine under /approvals —
    // prefix matching would light both at once.
    final isActive =
        location == path || (!exact && location.startsWith('$path/'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: collapsed ? label : '',
        child: InkWell(
          onTap: () {
            // In the phone drawer, close it — otherwise it stays over the
            // page the user just picked.
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
            context.go(path);
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.pink.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Active left bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: isActive ? 20 : 0,
                  decoration: BoxDecoration(
                    gradient: AppColors.ribbon,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: collapsed ? 10 : 8),
                Icon(
                  icon,
                  size: 19,
                  color: isActive ? AppColors.pink : context.c.txt3,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? context.c.txt : context.c.txt2,
                        fontSize: 13.5,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo({this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = small ? 28.0 : 32.0;
    // The real S mark, not a letter. The ribbon gradient stays out of this
    // tile: the mark already carries the full ribbon, and putting it on a
    // ribbon fill turns both to mud.
    return VistarBrandGlyph(size: s, radius: s * 0.28);
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.user, this.small = false});
  final User? user;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = small ? 32.0 : 36.0;
    final text = user?.initials ?? '?';
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        gradient: AppColors.ribbon,
        borderRadius: BorderRadius.circular(s * 0.3),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: s * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Topbar extends ConsumerWidget {
  const _Topbar({
    required this.user,
    required this.onMenuTap,
    required this.collapsed,
    this.compact = false,
  });

  final User? user;
  final VoidCallback onMenuTap;
  final bool collapsed;

  /// Phone width: the search box becomes an icon and the name beside the
  /// avatar is dropped, so the bar fits a 360px screen.
  final bool compact;

  /// Search runs on My Notes, which matches note numbers and objectives.
  static void _search(WidgetRef ref, BuildContext context, String text) {
    ref.read(notesSearchProvider.notifier).state = text.trim();
    context.go('/notes');
  }

  Future<void> _searchDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: ref.read(notesSearchProvider));
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.c.surface,
        title: Text('Search notes', style: TextStyle(color: context.c.txt, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Note number or objective'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(ctrl.text), child: const Text('Search')),
        ],
      ),
    );
    ctrl.dispose();
    if (text != null && context.mounted) _search(ref, context, text);
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v) async {
    switch (v) {
      case 'profile':
        if (user != null) await showProfileDialog(context, user!);
      case 'change_pw':
        final changed = await showChangePasswordDialog(context);
        if (!changed || !context.mounted) return;
        AppFeedback.success(context, 'Password changed. Please sign in with your new password.');
        await ref.read(authProvider.notifier).logout();
        ref.read(routerProvider).go('/login');
      case 'theme':
        // Resolve the *effective* brightness so toggling from "system"
        // flips to the opposite of what is currently on screen.
        ref.read(themeModeProvider.notifier).toggle(Theme.of(context).brightness);
      case 'logout':
        await ref.read(authProvider.notifier).logout();
        // A plain sign-in page: the next person to sign in on this browser
        // should start at their dashboard, not on this page.
        ref.read(routerProvider).go('/login');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
      decoration: BoxDecoration(
        color: context.c.bg2,
        border: Border(bottom: BorderSide(color: context.c.line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: compact ? 'Menu' : (collapsed ? 'Expand menu' : 'Collapse menu'),
            icon: Icon(
              collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: context.c.txt2,
            ),
            onPressed: onMenuTap,
          ),
          const SizedBox(width: 8),
          if (compact)
            IconButton(
              tooltip: 'Search notes',
              icon: Icon(Icons.search_rounded, color: context.c.txt2),
              onPressed: () => _searchDialog(context, ref),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _SearchBox(onSubmit: (t) => _search(ref, context, t)),
              ),
            ),
          const Spacer(),

          // Notes waiting for my decision. The badge only shows a real count.
          Builder(builder: (context) {
            final pending = ref.watch(pendingMyActionCountProvider).valueOrNull ?? 0;
            return IconButton(
              tooltip: pending == 0
                  ? 'No notes waiting for you'
                  : '$pending ${pending == 1 ? 'note' : 'notes'} waiting for your decision',
              icon: Badge(
                isLabelVisible: pending > 0,
                backgroundColor: AppColors.pink,
                label: Text(pending > 99 ? '99+' : '$pending'),
                child: Icon(Icons.notifications_outlined, color: context.c.txt2),
              ),
              onPressed: () => context.go('/approvals'),
            );
          }),

          const SizedBox(width: 4),

          // User menu
          PopupMenuButton<String>(
            tooltip: 'Account',
            child: Row(
              children: [
                _UserAvatar(user: user, small: true),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.c.txt,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user?.role.label ?? '',
                          style: TextStyle(
                            color: context.c.txt3,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, color: context.c.txt3, size: 16),
                ],
              ],
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 16),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'change_pw',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16),
                    SizedBox(width: 10),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              // Theme toggle. Labelled by the target, not the current state —
              // "Light mode" means "switch to light" — which is what a user
              // reads a menu action as.
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      context.c.isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(context.c.isDark ? 'Light mode' : 'Dark mode'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: context.c.bad),
                    const SizedBox(width: 10),
                    Text('Sign out',
                        style: TextStyle(color: context.c.bad)),
                  ],
                ),
              ),
            ],
            onSelected: (v) => _onMenu(context, ref, v),
          ),
        ],
      ),
    );
  }
}

/// The header search field. Enter opens My Notes filtered to the text.
class _SearchBox extends ConsumerStatefulWidget {
  const _SearchBox({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  ConsumerState<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends ConsumerState<_SearchBox> {
  late final _ctrl = TextEditingController(text: ref.read(notesSearchProvider));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cleared from the My Notes chip: empty the box too.
    ref.listen(notesSearchProvider, (_, next) {
      if (next != _ctrl.text) _ctrl.text = next;
    });
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _ctrl,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSubmit,
        style: TextStyle(color: context.c.txt, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search notes…',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: Icon(Icons.search_rounded, color: context.c.txt3, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
        ),
      ),
    );
  }
}
