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
    final search = ref.watch(notesSearchProvider).trim();
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 12),
              GradientButton(
                label: compact ? 'New' : 'Raise New Note',
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

          // The header search, shown so it can be seen and cleared here.
          if (search.isNotEmpty) ...[
            InputChip(
              avatar: const Icon(Icons.search_rounded, size: 16),
              label: Text('Results for "$search"'),
              onDeleted: () => ref.read(notesSearchProvider.notifier).state = '',
              deleteButtonTooltipMessage: 'Clear search',
            ),
            const SizedBox(height: 12),
          ],

          // Notes table
          Expanded(
            child: notesAsync.when(
              data: (page) => page.notes.isEmpty
                  ? EmptyState(
                      message: search.isNotEmpty
                          ? 'No notes match "$search".'
                          : activeFilter == null
                              ? (mineOnly
                                  ? 'You have not raised any notes yet.'
                                  : 'No notes yet.')
                              : 'No notes found for this filter.',
                      icon: Icons.description_outlined,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _NotesTable(
                            notes: page.notes,
                            meId: ref.watch(authProvider).user?.id,
                            showInitiator: !mineOnly,
                          ),
                        ),
                        // The server sends at most 100 at a time; say so
                        // rather than let a short list pass for all of them.
                        if (page.total > page.notes.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Showing the latest ${page.notes.length} of ${page.total} notes. '
                              'Use the status filters or the search box to find older ones.',
                              style: TextStyle(color: context.c.txt3, fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
              loading: () => ListView(
                children: List.generate(5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: ShimmerCard(height: 72),
                    )),
              ),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(filteredNotesProvider)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesTable extends StatelessWidget {
  const _NotesTable({required this.notes, required this.meId, this.showInitiator = false});
  final List<Note> notes;

  /// The signed-in user, to tell their own editable notes from the rest.
  final String? meId;

  /// When an admin views all notes, each row needs a "Raised By" column so it
  /// is clear whose note it is — otherwise the list is anonymous.
  final bool showInitiator;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) =>
          box.maxWidth < 720 ? _cards(context) : _table(context),
    );
  }

  Widget _table(BuildContext context) {
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
        _td(TextButton(
          onPressed: () => context.go(_target(n)),
          child: Text(_actionLabel(n)),
        )),
      ],
    );
  }

  /// A draft still being written, or a note sent back to be revised, opens the
  /// form — but only for its creator; the server refuses anyone else's edit
  /// (an admin browsing All Notes included). Everything else is read-only.
  String _target(Note n) =>
      n.editableBy(meId) ? '/notes/${n.id}/edit' : '/notes/${n.id}';

  String _actionLabel(Note n) {
    if (!n.editableBy(meId)) return 'View →';
    return n.isReturned ? 'Revise →' : 'Edit →';
  }

  /// Phones: a card per note instead of a seven-column table.
  Widget _cards(BuildContext context) {
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = notes[i];
        return VistarCard(
          onTap: () => context.go(_target(n)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(n.noteNumber,
                        style: TextStyle(color: context.c.txt3, fontSize: 12, fontFamily: 'monospace')),
                  ),
                  StatusPill(n.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(n.purposeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.c.txt, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(n.objectiveInDetail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.c.txt2, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showInitiator ? '${n.initiatorName} · ${formatDate(n.createdAt)}' : formatDate(n.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.c.txt3, fontSize: 12),
                    ),
                  ),
                  Text(_actionLabel(n),
                      style: const TextStyle(color: AppColors.pink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
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
