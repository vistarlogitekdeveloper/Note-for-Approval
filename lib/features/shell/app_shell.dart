import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/user.dart';
import '../../shared/widgets/vistar_brand.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 768;

    return Scaffold(
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
                  onMenuTap: isMobile
                      ? () => Scaffold.of(context).openDrawer()
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
      color: AppColors.bg2,
      child: Column(
        children: [
          // Brand row
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
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
                            color: AppColors.txt,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppStrings.company,
                          style: const TextStyle(
                            color: AppColors.txt3,
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
                    if (role?.canApprove ?? false)
                      _NavItem(icon: Icons.pending_actions_outlined, label: 'Pending Approvals', path: '/approvals', collapsed: collapsed),
                  ], collapsed: collapsed),
                  if (role?.canAdmin ?? false) ...[
                    _navGroup('Administration', [
                      _NavItem(icon: Icons.people_outlined, label: 'Users', path: '/admin/users', collapsed: collapsed),
                      _NavItem(icon: Icons.list_alt_outlined, label: 'Masters', path: '/admin/masters', collapsed: collapsed),
                      _NavItem(icon: Icons.history_outlined, label: 'Audit Log', path: '/admin/audit', collapsed: collapsed),
                    ], collapsed: collapsed),
                  ],
                ],
              ),
            ),
          ),

          // User block
          Container(
            padding: EdgeInsets.all(collapsed ? 8 : 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
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
                              style: const TextStyle(
                                color: AppColors.txt,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.role.label ?? '',
                              style: const TextStyle(
                                color: AppColors.txt3,
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
              style: const TextStyle(
                color: AppColors.txt3,
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
  });

  final IconData icon;
  final String label;
  final String path;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == path || location.startsWith('$path/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: collapsed ? label : '',
        child: InkWell(
          onTap: () => context.go(path),
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
                  color: isActive ? AppColors.pink : AppColors.txt3,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive ? AppColors.txt : AppColors.txt2,
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
  });

  final User? user;
  final VoidCallback onMenuTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: AppColors.txt2,
            ),
            onPressed: onMenuTap,
          ),
          const SizedBox(width: 8),
          // Search bar
          Container(
            height: 38,
            width: 260,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search_rounded, color: AppColors.txt3, size: 18),
                SizedBox(width: 8),
                Text('Search notes…',
                    style: TextStyle(color: AppColors.txt3, fontSize: 13.5)),
              ],
            ),
          ),
          const Spacer(),

          // Notification bell
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.txt2),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {},
          ),

          const SizedBox(width: 4),

          // User menu
          PopupMenuButton<String>(
            child: Row(
              children: [
                _UserAvatar(user: user, small: true),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'User',
                      style: const TextStyle(
                        color: AppColors.txt,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      user?.role.label ?? '',
                      style: const TextStyle(
                        color: AppColors.txt3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.txt3, size: 16),
              ],
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                child: const Row(
                  children: [
                    Icon(Icons.person_outline, size: 16),
                    SizedBox(width: 10),
                    Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'change_pw',
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16),
                    SizedBox(width: 10),
                    Text('Change Password'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: AppColors.bad),
                    const SizedBox(width: 10),
                    Text('Sign out',
                        style: TextStyle(color: AppColors.bad)),
                  ],
                ),
              ),
            ],
            onSelected: (v) async {
              if (v == 'logout') {
                await ref.read(authProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
