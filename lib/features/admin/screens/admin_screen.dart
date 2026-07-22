import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/common_widgets.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  // Not a static const any more: two tile accents are theme-aware, which needs
  // a BuildContext. Brand orange stays constant.
  List<_AdminTile> _tiles(BuildContext context) => [
        _AdminTile(
          icon: Icons.people_alt_outlined,
          title: 'Users',
          subtitle: 'Manage users and role assignments',
          path: '/admin/users',
          color: context.c.info,
        ),
        const _AdminTile(
          icon: Icons.list_alt_outlined,
          title: 'Purpose Masters',
          subtitle: 'Manage Purpose/Objective dropdown values',
          path: '/admin/masters',
          color: AppColors.orange,
        ),
        _AdminTile(
          icon: Icons.history_outlined,
          title: 'Audit Log',
          subtitle: 'Immutable record of all system actions',
          path: '/admin/audit',
          color: context.c.warn,
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administration',
            style: GoogleFonts.bricolageGrotesque(
              color: context.c.txt,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Manage the system configuration, users, and masters',
            style: TextStyle(color: context.c.txt3, fontSize: 14),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: LayoutBuilder(builder: (ctx, c) {
              final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: _tiles(context)
                    .map((t) => _AdminCard(tile: t))
                    .toList(),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AdminTile {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
  final Color color;
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.tile});
  final _AdminTile tile;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      onTap: () => context.go(tile.path),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tile.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tile.icon, color: tile.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tile.title,
                  style: TextStyle(
                    color: context.c.txt,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tile.subtitle,
                  style: TextStyle(
                      color: context.c.txt3, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: context.c.txt3),
        ],
      ),
    );
  }
}
