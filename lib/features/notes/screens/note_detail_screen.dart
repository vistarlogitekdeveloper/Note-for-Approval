import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/status_pill.dart';

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailProvider(id));
    final user = ref.watch(authProvider).user;

    return noteAsync.when(
      data: (note) => _NoteDetail(note: note, currentUser: user),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading note: $e',
            style: TextStyle(color: context.c.bad)),
      ),
    );
  }
}

class _NoteDetail extends ConsumerWidget {
  const _NoteDetail({required this.note, required this.currentUser});
  final Note note;
  final User? currentUser;

  /// Whether this user may decide the note right now.
  ///
  /// Mirrors `canActAt()` in the API's note.service.js, branch for branch — a
  /// button the server would refuse is as wrong as a missing one.
  ///
  /// STRICT: only the user the note NAMES at its CURRENT level may act. There is
  /// no admin override — an admin who is not named at the current level (whether
  /// off the chain entirely, or on it but at another step) sees no action
  /// buttons, exactly like anyone else. The server enforces the same rule.
  bool get _canApprove {
    final user = currentUser;
    if (user == null || note.status != NoteStatus.pendingApproval) return false;

    if (note.hasCustomChain) {
      return note.approverChain
          .any((a) => a.level == note.currentLevel && a.userId == user.id);
    }

    // Dormant global route — likewise strict: the holder of this level, no override.
    return user.hierarchyLevel == note.currentLevel;
  }

  /// The server allows a PATCH only from the note's own initiator, and only
  /// while the note is a draft or has been returned after a rejection. An
  /// admin cannot edit someone else's note, so role plays no part here.
  bool get _canEdit => note.editableBy(currentUser?.id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/notes'),
                          child: Text('My Notes',
                              style: TextStyle(color: context.c.txt3, fontSize: 13.5)),
                        ),
                        Text(' / ', style: TextStyle(color: context.c.txt3)),
                        Text(note.noteNumber,
                            style: TextStyle(
                                color: context.c.txt2, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.purposeLabel,
                      style: GoogleFonts.bricolageGrotesque(
                        color: context.c.txt,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusPill(note.status),
                        const SizedBox(width: 10),
                        if (note.status == NoteStatus.pendingApproval)
                          LevelPill(
                            current: note.currentLevel,
                            total: note.totalLevels,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Row(
                children: [
                  if (_canEdit)
                    GhostButton(
                      // A returned note is a different act from finishing a
                      // draft — the label should say which one this is.
                      label: note.isReturned ? 'Revise & resubmit' : 'Edit draft',
                      icon: note.isReturned
                          ? Icons.restart_alt_rounded
                          : Icons.edit_outlined,
                      onPressed: () => context.go('/notes/${note.id}/edit'),
                    ),
                  // Gated on status, not on pdf_url: the PDF regenerates on
                  // demand from DB data, so an approved note can be fetched
                  // even when the stored key is stale or the file was wiped.
                  if (note.hasPdf) ...[
                    if (_canEdit) const SizedBox(width: 12),
                    _DownloadPdfButton(note: note),
                  ],
                  // Approve / Reject / Send back — shown ONLY to the user named
                  // at the note's current level (see _canApprove). No admin
                  // override, so there is no "acting on someone else's level"
                  // case left to label.
                  if (_canApprove) ...[
                    const SizedBox(width: 12),
                    GhostButton(
                      label: 'Send back',
                      icon: Icons.reply_rounded,
                      onPressed: () => _showRemarkDialog(
                        context, ref, decision: _Decision.reassign),
                    ),
                    const SizedBox(width: 12),
                    GhostButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      danger: true,
                      onPressed: () => _showRemarkDialog(
                        context, ref, decision: _Decision.reject),
                    ),
                    const SizedBox(width: 12),
                    GradientButton(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      onPressed: () => _showRemarkDialog(
                        context, ref, decision: _Decision.approve),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Main content in two columns
          LayoutBuilder(builder: (ctx, c) {
            final twoCol = c.maxWidth > 900;
            final leftPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoteInfoCard(note: note),
                const SizedBox(height: 20),
                _AttachmentsCard(
                    noteId: note.id, attachments: note.attachments),
              ],
            );
            final rightPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only shown when the note carries its own route — a note on
                // the global hierarchy has nothing note-specific to say here.
                if (note.hasCustomChain) ...[
                  _ApproverChainCard(
                    chain: note.approverChain,
                    currentLevel: note.currentLevel,
                    status: note.status,
                  ),
                  const SizedBox(height: 20),
                ],
                _ApprovalTrailCard(
                  rounds: note.trailByRound,
                  currentLevel: note.currentLevel,
                  totalLevels: note.totalLevels,
                ),
              ],
            );

            if (twoCol) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: leftPanel),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: rightPanel),
                ],
              );
            }
            return Column(
              children: [leftPanel, const SizedBox(height: 20), rightPanel],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showRemarkDialog(BuildContext context, WidgetRef ref,
      {required _Decision decision}) async {
    final outcome = await showDialog<DecisionOutcome>(
      context: context,
      // A decision is irreversible; a stray tap outside must not be how it
      // gets abandoned mid-typing.
      barrierDismissible: false,
      builder: (_) => _RemarkDialog(note: note, decision: decision),
    );
    if (outcome == null || !context.mounted) return;

    // Everything that counted this note is now wrong.
    ref.invalidate(noteDetailProvider(note.id));
    ref.invalidate(pendingApprovalsProvider);
    ref.invalidate(myNotesProvider);
    ref.invalidate(filteredNotesProvider);
    ref.invalidate(recentNotesProvider);
    ref.invalidate(dashboardStatsProvider);

    // Mail and PDF run after the decision commits and are best-effort, so the
    // decision can succeed while notification does not. Say which happened
    // rather than implying everything worked.
    final buffer = StringBuffer('${decision.pastMessage}.');
    if (!outcome.emailSent) {
      buffer.write(' Email was not sent');
      buffer.write(outcome.emailIssue == null ? '.' : ' (${outcome.emailIssue}).');
    }
    if (decision == _Decision.approve && outcome.pdfError != null) {
      buffer.write(' PDF could not be generated.');
    }

    if (outcome.emailSent && outcome.pdfError == null) {
      AppFeedback.success(context, buffer.toString());
    } else {
      AppFeedback.info(context, buffer.toString());
    }
  }
}

/// The three things an approver can do to a note awaiting them. `wire` is not
/// sent (each has its own endpoint) — it exists so the mapping to the API verb
/// is stated once, next to everything else that differs per decision.
enum _Decision {
  approve(
    title: 'Approve Note',
    actionLabel: 'Approve',
    busyLabel: 'Approving…',
    pastMessage: 'Note approved',
    hint: 'Enter your approval remark…',
    remarkRequired: false,
  ),
  reject(
    title: 'Reject Note',
    actionLabel: 'Reject',
    busyLabel: 'Rejecting…',
    pastMessage: 'Note rejected',
    hint: 'Enter rejection reason…',
    remarkRequired: true,
  ),
  reassign(
    title: 'Send Back for Revision',
    actionLabel: 'Send back',
    busyLabel: 'Sending…',
    pastMessage: 'Note sent back for revision',
    hint: 'What should the creator change before resubmitting?',
    remarkRequired: true,
  );

  const _Decision({
    required this.title,
    required this.actionLabel,
    required this.busyLabel,
    required this.pastMessage,
    required this.hint,
    required this.remarkRequired,
  });

  final String title;
  final String actionLabel;
  final String busyLabel;
  final String pastMessage;
  final String hint;

  /// Approve may be confirmed with no remark (the server auto-fills one);
  /// reject and reassign both need a reason the creator will read.
  final bool remarkRequired;
}

/// Fetches the approved note's PDF and saves it.
///
/// Stateful only so the button can show it is working — the request needs the
/// Bearer token, so this cannot be a plain link and there is a real round trip
/// to wait for.
class _DownloadPdfButton extends ConsumerStatefulWidget {
  const _DownloadPdfButton({required this.note});
  final Note note;

  @override
  ConsumerState<_DownloadPdfButton> createState() => _DownloadPdfButtonState();
}

class _DownloadPdfButtonState extends ConsumerState<_DownloadPdfButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(notesRepositoryProvider).downloadNotePdf(widget.note.id);
      await downloadBytes(
        bytes,
        '${widget.note.noteNumber}.pdf',
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      AppFeedback.success(context, 'Downloaded ${widget.note.noteNumber}.pdf');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhostButton(
      label: _busy ? 'Preparing…' : 'Download PDF',
      icon: Icons.picture_as_pdf_outlined,
      onPressed: _busy ? null : _download,
    );
  }
}

/// The approve/reject confirmation.
///
/// A separate stateful widget so the remark controller is disposed, the call
/// can be awaited with the dialog still open (the user sees it working, and
/// cannot fire it twice), and a failure is reported INSIDE the dialog instead
/// of vanishing behind a dialog that already closed.
class _RemarkDialog extends ConsumerStatefulWidget {
  const _RemarkDialog({required this.note, required this.decision});
  final Note note;
  final _Decision decision;

  @override
  ConsumerState<_RemarkDialog> createState() => _RemarkDialogState();
}

class _RemarkDialogState extends ConsumerState<_RemarkDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final decision = widget.decision;
    final remark = _ctrl.text.trim();
    // Approve may go through with no remark (the server records one); reject and
    // reassign both need a reason the creator will read.
    if (decision.remarkRequired && remark.isEmpty) {
      setState(() => _error = 'A remark is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(notesRepositoryProvider);
    try {
      final outcome = switch (decision) {
        _Decision.approve => await repo.approveNote(widget.note.id, remark),
        _Decision.reject => await repo.rejectNote(widget.note.id, remark),
        _Decision.reassign => await repo.reassignNote(widget.note.id, remark),
      };
      if (!mounted) return;
      Navigator.of(context).pop(outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  String get _lead => switch (widget.decision) {
        _Decision.approve => widget.note.currentLevel >= widget.note.totalLevels
            ? 'This is the final level — the note will be fully approved.'
            : 'This note will be forwarded to the next level.',
        _Decision.reject =>
          'This ends the approval workflow. The note is rejected and cannot be edited or resubmitted.',
        _Decision.reassign =>
          'This sends the note back to its creator to revise the hierarchy. Already-approved levels stay approved — when resubmitted it resumes from level ${widget.note.currentLevel}, not the start.',
      };

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final required = decision.remarkRequired;
    return AlertDialog(
      backgroundColor: context.c.surface,
      title: Text(decision.title,
          style: TextStyle(color: context.c.txt, fontSize: 17)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lead,
              style: TextStyle(color: context.c.txt2, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              autofocus: true,
              enabled: !_busy,
              style: TextStyle(color: context.c.txt),
              decoration: InputDecoration(
                labelText: required ? 'Remark *' : 'Remark (optional)',
                hintText: decision.hint,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 15, color: context.c.bad),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: context.c.bad, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        decision == _Decision.approve
            ? GradientButton(
                label: _busy ? decision.busyLabel : decision.actionLabel,
                small: true,
                loading: _busy,
                onPressed: _busy ? null : _submit,
              )
            : GhostButton(
                label: _busy ? decision.busyLabel : decision.actionLabel,
                danger: decision == _Decision.reject,
                onPressed: _busy ? null : _submit,
              ),
      ],
    );
  }
}

// ── Info Card ──────────────────────────────────────────────────────────────────
class _NoteInfoCard extends StatelessWidget {
  const _NoteInfoCard({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Note Information'),
          const SizedBox(height: 20),
          _InfoRow('Note Number', note.noteNumber),
          _InfoRow('Raised By', note.initiatorName),
          _InfoRow('Email', note.initiatorEmail),
          _InfoRow('Date Submitted', formatDateTime(note.createdAt)),
          _InfoRow('Purpose / Objective', note.purposeLabel),
          Divider(height: 24, color: context.c.line),
          _InfoRow('Objective in Detail', note.objectiveInDetail,
              multiLine: true),
          const SizedBox(height: 12),
          _InfoRow('Brief Note', note.briefNote, multiLine: true),
          const SizedBox(height: 12),
          _InfoRow('Expected Benefit / Loss', note.benefit, multiLine: true),
          const SizedBox(height: 12),
          _InfoRow('Cost Impact', note.costImpact, multiLine: true),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.multiLine = false});
  final String label;
  final String value;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    if (multiLine) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.c.txt3,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: context.c.txt, fontSize: 14, height: 1.6)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: TextStyle(
                    color: context.c.txt3, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: context.c.txt,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Attachments Card ───────────────────────────────────────────────────────────
class _AttachmentsCard extends ConsumerStatefulWidget {
  const _AttachmentsCard({required this.noteId, required this.attachments});
  final String noteId;
  final List<NoteAttachment> attachments;

  @override
  ConsumerState<_AttachmentsCard> createState() => _AttachmentsCardState();
}

class _AttachmentsCardState extends ConsumerState<_AttachmentsCard> {
  /// Ids currently downloading, so each row can show its own spinner and
  /// cannot be fired twice.
  final _busy = <String>{};

  List<NoteAttachment> get attachments => widget.attachments;

  Future<void> _download(NoteAttachment a) async {
    if (_busy.contains(a.id)) return;
    setState(() => _busy.add(a.id));
    try {
      final bytes = await ref
          .read(notesRepositoryProvider)
          .downloadAttachment(widget.noteId, a.id);
      await downloadBytes(bytes, a.fileName, mimeType: a.mimeType);
      if (!mounted) return;
      AppFeedback.success(context, 'Downloaded ${a.fileName}');
    } catch (e) {
      if (!mounted) return;
      // FILE_MISSING is the common one: the object is gone from disk because
      // Render wiped it on deploy, while the row still points at it.
      AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(a.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Attachments'),
          const SizedBox(height: 16),
          if (attachments.isEmpty)
            Text('No attachments',
                style: TextStyle(color: context.c.txt3, fontSize: 13.5))
          else
            Column(
              children: attachments.map((a) {
                final busy = _busy.contains(a.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: busy ? null : () => _download(a),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.c.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.c.line),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file_rounded,
                                size: 18, color: context.c.txt3),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(a.fileName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.c.txt2, fontSize: 13.5)),
                            ),
                            if (a.sizeBytes != null)
                              Text(
                                formatBytes(a.sizeBytes),
                                style: TextStyle(
                                    color: context.c.txt3, fontSize: 12),
                              ),
                            const SizedBox(width: 8),
                            if (busy)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Icon(Icons.download_rounded,
                                  size: 18, color: context.c.txt3),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ── Approver Chain Card ──────────────────────────────────────────────────────
//
// The route this specific note takes, when it defines its own. Shows who is
// responsible at each level and where the note currently sits — the question
// an initiator actually has while waiting.
class _ApproverChainCard extends StatelessWidget {
  const _ApproverChainCard({
    required this.chain,
    required this.currentLevel,
    required this.status,
  });

  final List<NoteApprover> chain;
  final int currentLevel;
  final NoteStatus status;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Approval Route'),
          const SizedBox(height: 6),
          Text(
            'This note follows its own route rather than the standard hierarchy.',
            style: TextStyle(color: context.c.txt3, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          ...chain.map((a) {
            // Only meaningful while the note is actually moving: a rejected or
            // approved note is not "waiting" on anyone.
            final isCurrent =
                status == NoteStatus.pendingApproval && a.level == currentLevel;
            final isDone = status == NoteStatus.approved || a.level < currentLevel;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.pink.withValues(alpha: 0.18)
                          : context.c.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? AppColors.pink : context.c.line2,
                      ),
                    ),
                    child: isDone
                        ? Icon(Icons.check_rounded,
                            size: 15, color: context.c.ok)
                        : Text('L${a.level}',
                            style: TextStyle(
                              color: isCurrent ? AppColors.pink : context.c.txt3,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.userName,
                            style: TextStyle(
                              color: isCurrent ? context.c.txt : context.c.txt2,
                              fontSize: 13.5,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w600,
                            )),
                        Text(
                          a.roleName.isEmpty
                              ? a.userEmail
                              : '${a.userEmail} · ${a.roleName}',
                          style: TextStyle(
                              color: context.c.txt3, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Text('Awaiting',
                          style: TextStyle(
                              color: AppColors.pink,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Approval Trail Card ────────────────────────────────────────────────────────
class _ApprovalTrailCard extends StatelessWidget {
  const _ApprovalTrailCard({
    required this.rounds,
    required this.currentLevel,
    required this.totalLevels,
  });

  /// Decisions grouped by attempt, oldest first. A note rejected once and
  /// resubmitted has two rounds; the earlier one is history and must stay
  /// visible, because "why was this sent back?" is the question the trail
  /// exists to answer.
  final List<MapEntry<int, List<ApprovalAction>>> rounds;
  final int currentLevel;
  final int totalLevels;

  int get _count => rounds.fold(0, (n, r) => n + r.value.length);

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Approval Trail'),
          const SizedBox(height: 16),
          // Progress bar
          LinearProgressIndicator(
            value: totalLevels > 0 ? currentLevel / totalLevels : 0,
            backgroundColor: context.c.surface3,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.pink),
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '$currentLevel of $totalLevels levels completed',
              style:
                  TextStyle(color: context.c.txt3, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (_count == 0)
            Text('No approval actions yet.',
                style: TextStyle(color: context.c.txt3, fontSize: 13.5))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final round in rounds) ...[
                  // A single-round note is the normal case and does not need a
                  // header; once a note has been sent back, saying which
                  // attempt you are looking at is the whole point.
                  if (rounds.length > 1) _RoundHeader(round: round.key),
                  ...round.value.map((a) => _ApprovalStep(action: a)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Separates one attempt from the next in the trail.
class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.round});
  final int round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppColors.violet.withValues(alpha: 0.35)),
            ),
            child: Text(
              round == 1 ? 'First submission' : 'Resubmission $round',
              style: const TextStyle(
                color: AppColors.violet,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: context.c.line, height: 1)),
        ],
      ),
    );
  }
}

class _ApprovalStep extends StatelessWidget {
  const _ApprovalStep({required this.action});
  final ApprovalAction action;

  @override
  Widget build(BuildContext context) {
    final isApproved = action.isApproved;
    final color = isApproved ? context.c.ok : context.c.bad;
    final icon = isApproved
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${action.level}: ${action.roleName}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    action.approverName,
                    style: TextStyle(
                        color: context.c.txt, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                formatDateTime(action.actedAt),
                style: TextStyle(
                    color: context.c.txt3, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${action.remark}"',
            style: TextStyle(
                color: context.c.txt2,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
