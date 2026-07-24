import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/scope_toggle.dart';
import '../../../shared/widgets/status_pill.dart';

class MyNotesScreen extends ConsumerWidget {
  const MyNotesScreen({super.key});

  static const _filters = [
    (null, 'All'),
    ('draft', 'Drafts'),
    ('pendingApproval', 'Pending'),
    ('returned', 'Returned'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(notesFilterProvider);
    final notesAsync = ref.watch(filteredNotesProvider);
    // Only an admin gets the My/All choice; everyone else only ever sees their
    // own notes, so the toggle is hidden and the scope stays "mine".
    final isAdmin = ref.watch(authProvider).user?.role.canAdmin ?? false;
    final mineOnly = !isAdmin || ref.watch(notesScopeMineProvider);

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
                  Text(mineOnly ? 'My Notes' : 'All Notes',
                      style: GoogleFonts.bricolageGrotesque(
                        color: context.c.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  Text(
                      mineOnly
                          ? 'All notes you have raised'
                          : 'Every note across the system',
                      style: TextStyle(color: context.c.txt3, fontSize: 14)),
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

          // Scope toggle — admins only.
          if (isAdmin) ...[
            ScopeToggle(
              mineOnly: ref.watch(notesScopeMineProvider),
              onChanged: (v) =>
                  ref.read(notesScopeMineProvider.notifier).state = v,
            ),
            const SizedBox(height: 16),
          ],

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
                  : _NotesTable(notes: notes, showInitiator: !mineOnly),
              loading: () => ListView(
                children: List.generate(5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerCard(height: 72),
                    )),
              ),
              error: (e, _) =>
                  Center(child: Text('Error: $e',
                      style: TextStyle(color: context.c.bad))),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTable extends StatelessWidget {
  const _NotesTable({required this.notes, this.showInitiator = false});
  final List<Note> notes;

  /// When an admin views all notes, each row needs a "Raised By" column so it
  /// is clear whose note it is — otherwise the list is anonymous.
  final bool showInitiator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.c.line),
        borderRadius: BorderRadius.circular(16),
        color: context.c.surface,
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
            //
            // A "Raised By" column is inserted after Note # only in all-notes
            // mode, so the width map and cell lists are built to match.
            columnWidths: {
              0: const IntrinsicColumnWidth(), // Note #
              if (showInitiator) 1: const IntrinsicColumnWidth(), // Raised By
              (showInitiator ? 2 : 1): const FlexColumnWidth(2), // Purpose
              (showInitiator ? 3 : 2): const FlexColumnWidth(3), // Objective
              (showInitiator ? 4 : 3): const IntrinsicColumnWidth(), // Status
              (showInitiator ? 5 : 4): const IntrinsicColumnWidth(), // Date
              (showInitiator ? 6 : 5): const IntrinsicColumnWidth(), // Action
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(color: context.c.surface2),
                children: [
                  _th(context, 'Note #'),
                  if (showInitiator) _th(context, 'Raised By'),
                  _th(context, 'Purpose'),
                  _th(context, 'Objective'),
                  _th(context, 'Status'),
                  _th(context, 'Date'),
                  _th(context, ''),
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
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.c.line)),
      ),
      children: [
        _td(Text(n.noteNumber,
            style: TextStyle(
              color: context.c.txt3,
              fontSize: 12,
              fontFamily: 'monospace',
            ))),
        if (showInitiator)
          _td(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(n.initiatorName,
                  style: TextStyle(
                    color: context.c.txt,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (n.initiatorEmail.isNotEmpty)
                Text(n.initiatorEmail,
                    style: TextStyle(color: context.c.txt3, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          )),
        _td(Text(n.purposeLabel,
            style: TextStyle(
              color: context.c.txt,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        _td(Text(truncate(n.objectiveInDetail, 80),
            style: TextStyle(color: context.c.txt2, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis)),
        _td(StatusPill(n.status)),
        _td(Text(formatDate(n.createdAt),
            style: TextStyle(color: context.c.txt3, fontSize: 12.5))),
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

  Widget _th(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.c.txt3,
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
