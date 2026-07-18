import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/status_pill.dart';

class MyNotesScreen extends ConsumerWidget {
  const MyNotesScreen({super.key});

  static const _filters = [
    (null, 'All'),
    ('draft', 'Drafts'),
    ('pendingApproval', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(notesFilterProvider);
    final notesAsync = ref.watch(filteredNotesProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Notes',
                      style: GoogleFonts.bricolageGrotesque(
                        color: AppColors.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  const Text('All notes you have raised',
                      style: TextStyle(color: AppColors.txt3, fontSize: 14)),
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
          const SizedBox(height: 20),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final (val, label) = f;
                final isActive = activeFilter == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(notesFilterProvider.notifier).state = val,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.pink.withValues(alpha: 0.15)
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppColors.pink : AppColors.line,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive ? AppColors.pink : AppColors.txt2,
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Notes table
          Expanded(
            child: notesAsync.when(
              data: (notes) => notes.isEmpty
                  ? EmptyState(
                      message: 'No notes found for this filter.',
                      icon: Icons.description_outlined,
                    )
                  : _NotesTable(notes: notes),
              loading: () => Column(
                children: List.generate(5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerCard(height: 72),
                    )),
              ),
              error: (e, _) =>
                  Center(child: Text('Error: $e',
                      style: const TextStyle(color: AppColors.bad))),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTable extends StatelessWidget {
  const _NotesTable({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            // Intrinsic, not fixed, for every column holding a self-sizing
            // widget. The old fixed widths were measured against one sample of
            // content: 110px could not hold the "Approved" pill (85px of pill
            // in 78px of usable width, hence a 7px overflow) and 100px made
            // "View →" wrap onto two lines. Only the two free-text columns
            // flex, because they are the ones that should absorb slack.
            columnWidths: const {
              0: IntrinsicColumnWidth(), // Note #
              1: FlexColumnWidth(2), // Purpose
              2: FlexColumnWidth(3), // Objective
              3: IntrinsicColumnWidth(), // Status pill
              4: IntrinsicColumnWidth(), // Date
              5: IntrinsicColumnWidth(), // Action
            },
            children: [
              // Header
              TableRow(
                decoration: const BoxDecoration(color: AppColors.surface2),
                children: [
                  _th('Note #'),
                  _th('Purpose'),
                  _th('Objective'),
                  _th('Status'),
                  _th('Date'),
                  _th(''),
                ],
              ),
              ...notes.map((n) => _noteRow(context, n)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _noteRow(BuildContext context, Note n) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      children: [
        _td(Text(n.noteNumber,
            style: const TextStyle(
              color: AppColors.txt3,
              fontSize: 12,
              fontFamily: 'monospace',
            ))),
        _td(Text(n.purposeLabel,
            style: const TextStyle(
              color: AppColors.txt,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        _td(Text(truncate(n.objectiveInDetail, 80),
            style: const TextStyle(color: AppColors.txt2, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        _td(StatusPill(n.status)),
        _td(Text(formatDate(n.createdAt),
            style: const TextStyle(color: AppColors.txt3, fontSize: 12.5))),
        // A draft is still being written and a returned note is waiting to be
        // revised — both open the form. Anything else is read-only.
        _td(
          TextButton(
            onPressed: () => context.go(
              n.isDraft || n.isReturned
                  ? '/notes/${n.id}/edit'
                  : '/notes/${n.id}',
            ),
            child: Text(n.isDraft
                ? 'Edit →'
                : n.isReturned
                    ? 'Revise →'
                    : 'View →'),
          ),
        ),
      ],
    );
  }

  Widget _th(String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.txt3,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _td(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: child,
      );
}
