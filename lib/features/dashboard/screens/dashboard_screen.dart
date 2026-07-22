import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/notes/models/note.dart';
import '../../../features/notes/providers/notes_provider.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/status_pill.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentAsync = ref.watch(recentNotesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.bricolageGrotesque(
                      color: context.c.txt,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Welcome back, ${user?.name ?? 'User'}',
                    style: TextStyle(color: context.c.txt3, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Raise New Note',
                icon: Icons.add_rounded,
                onPressed: () => context.go('/notes/new'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── KPI Cards ───────────────────────────────────────────────────
          statsAsync.when(
            data: (stats) => _KpiGrid(stats: stats, user: user),
            loading: () => const _KpiGridShimmer(),
            error: (e, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 32),

          // ── Pending Queue (approvers only) ───────────────────────────────
          if (user?.role.canApprove ?? false) ...[
            SectionHeader(
              'Pending My Action',
              trailing: TextButton(
                onPressed: () => context.go('/approvals'),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (s) => s.pendingMyAction > 0
                  ? _PendingBanner(count: s.pendingMyAction)
                  : const _NoPendingBanner(),
              loading: () => const ShimmerCard(height: 72),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),
          ],

          // ── Recent Notes ─────────────────────────────────────────────────
          SectionHeader(
            'Recent Notes',
            trailing: TextButton(
              onPressed: () => context.go('/notes'),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 12),
          recentAsync.when(
            data: (notes) => notes.isEmpty
                ? EmptyState(
                    message: 'No notes yet. Raise your first note for approval.',
                    icon: Icons.description_outlined,
                    action: GradientButton(
                      label: 'Raise a Note',
                      icon: Icons.add_rounded,
                      onPressed: () => context.go('/notes/new'),
                    ),
                  )
                : _NotesList(notes: notes),
            loading: () => Column(
              children: List.generate(3, (_) => const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: ShimmerCard(height: 80),
              )),
            ),
            error: (e, _) => Text('Error: $e',
                style: TextStyle(color: context.c.bad)),
          ),
        ],
      ),
    );
  }
}

/// The KPI tiles size themselves by a FIXED height, deliberately not by an
/// aspect ratio.
///
/// With `childAspectRatio` the tile height is derived from its width, so at
/// narrow-but-still-multi-column widths the tiles became shorter than the
/// content they hold — a 38px icon, a 32px number and a label cannot fit in
/// ~133px — and every card reported a bottom overflow.
///
/// `maxCrossAxisExtent` also replaces the hand-rolled breakpoints: the grid
/// fits as many columns as it can at up to 320px each, so it stays responsive
/// without any width thresholds to keep in sync.
const kpiGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 230,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  mainAxisExtent: 124,
);

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.stats, required this.user});
  final DashboardStats stats;
  final User? user;

  /// Opens My Notes already filtered to the slice this card counts, so the
  /// number and the list the user lands on always agree.
  void _open(BuildContext context, WidgetRef ref, String? status) {
    ref.read(notesFilterProvider.notifier).state = status;
    context.go('/notes');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView(
      gridDelegate: kpiGridDelegate,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        KpiCard(
          label: 'Total Notes',
          value: '${stats.totalNotes}',
          icon: Icons.description_outlined,
          color: context.c.info,
          onTap: () => _open(context, ref, null),
        ),
        // Drafts were missing, which made the totals look wrong: the API counts
        // drafts in `total`, so with any draft present Total was larger than
        // the cards beneath it and there was nothing to account for the gap.
        KpiCard(
          label: 'Drafts',
          value: '${stats.draftNotes}',
          icon: Icons.edit_note_rounded,
          color: context.c.txt3,
          onTap: () => _open(context, ref, NoteStatus.draft.wireValue),
        ),
        KpiCard(
          label: 'Pending',
          value: '${stats.pendingNotes}',
          icon: Icons.pending_actions_outlined,
          color: context.c.warn,
          onTap: () =>
              _open(context, ref, NoteStatus.pendingApproval.wireValue),
        ),
        KpiCard(
          label: 'Approved',
          value: '${stats.approvedNotes}',
          icon: Icons.check_circle_outline_rounded,
          color: context.c.ok,
          onTap: () => _open(context, ref, NoteStatus.approved.wireValue),
        ),
        KpiCard(
          label: 'Rejected',
          value: '${stats.rejectedNotes}',
          icon: Icons.cancel_outlined,
          color: context.c.bad,
          onTap: () => _open(context, ref, NoteStatus.rejected.wireValue),
        ),
      ],
    );
  }
}

class _KpiGridShimmer extends StatelessWidget {
  const _KpiGridShimmer();

  @override
  Widget build(BuildContext context) {
    // Same delegate as the real grid, so the layout does not jump when the
    // stats land.
    return GridView(
      gridDelegate: kpiGridDelegate,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(5, (_) => const ShimmerCard(height: 124)),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.warn.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_outlined,
              color: context.c.warn, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'You have $count ${count == 1 ? 'note' : 'notes'} waiting for your approval.',
              style: TextStyle(color: context.c.txt, fontSize: 14.5),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/approvals'),
            child: const Text('Review now →'),
          ),
        ],
      ),
    );
  }
}

class _NoPendingBanner extends StatelessWidget {
  const _NoPendingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.ok.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.c.ok.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: context.c.ok, size: 24),
          SizedBox(width: 12),
          Text('No pending approvals — all caught up!',
              style: TextStyle(color: context.c.txt2, fontSize: 14)),
        ],
      ),
    );
  }
}

class _NotesList extends StatelessWidget {
  const _NotesList({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: notes
          .take(5)
          .map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NoteRow(note: n),
              ))
          .toList(),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      onTap: () => context.go('/notes/${note.id}'),
      child: Row(
        children: [
          // Number badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.c.surface3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              note.noteNumber,
              style: TextStyle(
                color: context.c.txt2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.purposeLabel,
                  style: TextStyle(
                    color: context.c.txt,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  truncate(note.objectiveInDetail, 80),
                  style: TextStyle(color: context.c.txt3, fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(note.status),
              const SizedBox(height: 4),
              Text(
                timeAgo(note.createdAt),
                style: TextStyle(color: context.c.txt3, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
