import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../notes/models/note.dart';
import '../../notes/providers/notes_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/status_pill.dart';

/// What this user has personally approved and rejected.
///
/// An approver who raises no notes of their own had nowhere to see their own
/// work: My Notes is initiator-only, the audit log is admin-only, and the
/// dashboard's status counts describe NOTES, not decisions — a note you
/// rejected that was later revised and approved counts there as "approved".
/// This reads the decision record instead, so it answers "what have I done".
class MyDecisionsScreen extends ConsumerWidget {
  const MyDecisionsScreen({super.key});

  static const _filters = [
    (null, 'All'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(myDecisionsFilterProvider);
    final async = ref.watch(myDecisionsProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Decisions',
                        style: GoogleFonts.bricolageGrotesque(
                          color: context.c.txt,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        )),
                    Text('Every note you have approved or rejected',
                        style: TextStyle(color: context.c.txt3, fontSize: 14)),
                  ],
                ),
              ),
              GhostButton(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(myDecisionsProvider),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lifetime tallies. Deliberately from the server's meta rather than
          // counted off the visible page, so filtering or paging cannot make
          // the headline numbers drift.
          async.when(
            loading: () => const Row(children: [
              Expanded(child: ShimmerCard(height: 86)),
              SizedBox(width: 12),
              Expanded(child: ShimmerCard(height: 86)),
              SizedBox(width: 12),
              Expanded(child: ShimmerCard(height: 86)),
            ]),
            error: (_, __) => const SizedBox.shrink(),
            data: (page) => Row(
              children: [
                Expanded(
                  child: _Tally(
                    label: 'Decisions made',
                    value: page.approved + page.rejected,
                    color: context.c.info,
                    icon: Icons.gavel_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tally(
                    label: 'Approved by me',
                    value: page.approved,
                    color: context.c.ok,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tally(
                    label: 'Rejected by me',
                    value: page.rejected,
                    color: context.c.bad,
                    icon: Icons.cancel_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final (val, label) = f;
                final isActive = active == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(myDecisionsFilterProvider.notifier)
                        .state = val,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.pink.withValues(alpha: 0.15)
                            : context.c.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppColors.pink : context.c.line,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive ? AppColors.pink : context.c.txt2,
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: async.when(
              loading: () => Column(
                children: List.generate(
                  4,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: ShimmerCard(height: 84),
                  ),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Could not load your decisions.\n$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.c.bad)),
              ),
              data: (page) => page.decisions.isEmpty
                  ? EmptyState(
                      message: active == null
                          ? 'You have not approved or rejected any notes yet.'
                          : 'Nothing here under this filter.',
                      icon: Icons.history_rounded,
                    )
                  : ListView.builder(
                      itemCount: page.decisions.length,
                      itemBuilder: (_, i) =>
                          _DecisionRow(decision: page.decisions[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$value',
                    style: TextStyle(
                      fontFamily: 'BricolageGrotesque',
                      color: context.c.txt,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    )),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.c.txt3, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});
  final MyDecision decision;

  @override
  Widget build(BuildContext context) {
    final color = decision.isApproved ? context.c.ok : context.c.bad;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VistarCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.go('/notes/${decision.noteId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  decision.isApproved
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  decision.isApproved ? 'You approved' : 'You rejected',
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    decision.noteNumber,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.c.txt3,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const Spacer(),
                Text(formatDate(decision.actedAt),
                    style: TextStyle(
                        color: context.c.txt3, fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              truncate(decision.noteObjective, 110),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.c.txt2, fontSize: 13.5),
            ),
            if (decision.remark.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '“${decision.remark}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.c.txt3,
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Chip('Level ${decision.level}'),
                if (decision.roleName.isNotEmpty) _Chip(decision.roleName),
                // Which attempt — only meaningful once a note has been sent
                // back and resubmitted.
                if (decision.revision > 1) _Chip('Round ${decision.revision}'),
                const SizedBox(width: 2),
                // Where the note ended up, which is not always what you
                // decided: you may have approved it and a later level rejected
                // it, or rejected it and seen it revised and approved.
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('now: ',
                      style: TextStyle(color: context.c.txt3, fontSize: 11.5)),
                  StatusPill(decision.noteStatus),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: context.c.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.c.line2),
      ),
      child: Text(text,
          style: TextStyle(color: context.c.txt3, fontSize: 11.5)),
    );
  }
}
