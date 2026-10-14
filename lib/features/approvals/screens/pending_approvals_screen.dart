import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/notes/models/note.dart';
import '../../../features/notes/providers/notes_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/status_pill.dart';

class PendingApprovalsScreen extends ConsumerWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingApprovalsProvider);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 28),
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
                    Text(
                      'Pending Approvals',
                      style: GoogleFonts.bricolageGrotesque(
                        color: context.c.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Notes awaiting your action',
                      style: TextStyle(color: context.c.txt3, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // A queue fills up while you are looking at it, and nothing
              // pushes to the client — without this the only way to see a new
              // note is to navigate away and back.
              compact
                  ? IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => ref
                        ..invalidate(pendingApprovalsProvider)
                        ..invalidate(pendingMyActionCountProvider),
                    )
                  : GhostButton(
                      label: 'Refresh',
                      icon: Icons.refresh_rounded,
                      onPressed: () => ref
                        ..invalidate(pendingApprovalsProvider)
                        ..invalidate(pendingMyActionCountProvider),
                    ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: approvalsAsync.when(
              data: (notes) => notes.isEmpty
                  ? const EmptyState(
                      message:
                          'No notes pending your approval.\nYou\'re all caught up!',
                      icon: Icons.task_alt_rounded,
                    )
                  : _ApprovalGrid(notes: notes),
              loading: () => ListView(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 140),
                  ),
                ),
              ),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(pendingApprovalsProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalGrid extends StatelessWidget {
  const _ApprovalGrid({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _ApprovalCard(note: notes[i]),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      onTap: () => context.go('/notes/${note.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap: number, level and age do not fit on one line on a phone.
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.c.surface3,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  note.noteNumber,
                  style: TextStyle(
                    color: context.c.txt3,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              LevelPill(
                  current: note.currentLevel, total: note.totalLevels),
              Text(
                timeAgo(note.updatedAt),
                style:
                    TextStyle(color: context.c.txt3, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.purposeLabel,
            style: TextStyle(
              color: context.c.txt,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            truncate(note.objectiveInDetail, 120),
            style:
                TextStyle(color: context.c.txt2, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          Divider(color: context.c.line, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: context.c.txt3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  note.initiatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.c.txt3, fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 10),
              // One action, honestly named. A decision needs the note read and
              // a remark written, which happens on the note itself — the old
              // "Reject" here only opened the note, same as "Approve".
              GradientButton(
                label: 'Review',
                icon: Icons.arrow_forward_rounded,
                small: true,
                onPressed: () => context.go('/notes/${note.id}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
