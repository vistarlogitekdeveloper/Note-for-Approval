import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../../../shared/models/user.dart';
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
            style: const TextStyle(color: AppColors.bad)),
      ),
    );
  }
}

class _NoteDetail extends ConsumerWidget {
  const _NoteDetail({required this.note, required this.currentUser});
  final Note note;
  final User? currentUser;

  bool get _canApprove =>
      (currentUser?.role.canApprove ?? false) &&
      note.status == NoteStatus.pendingApproval;

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
                          child: const Text('My Notes',
                              style: TextStyle(color: AppColors.txt3, fontSize: 13.5)),
                        ),
                        const Text(' / ', style: TextStyle(color: AppColors.txt3)),
                        Text(note.noteNumber,
                            style: const TextStyle(
                                color: AppColors.txt2, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.purposeLabel,
                      style: GoogleFonts.bricolageGrotesque(
                        color: AppColors.txt,
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
                  if (note.pdfUrl != null)
                    GhostButton(
                      label: 'Download PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      onPressed: () {/* open PDF */},
                    ),
                  if (_canApprove) ...[
                    const SizedBox(width: 12),
                    GhostButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      danger: true,
                      onPressed: () => _showRemarkDialog(
                        context, ref, isApprove: false),
                    ),
                    const SizedBox(width: 12),
                    GradientButton(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      onPressed: () => _showRemarkDialog(
                        context, ref, isApprove: true),
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
                _AttachmentsCard(attachments: note.attachments),
              ],
            );
            final rightPanel = _ApprovalTrailCard(
              trail: note.approvalTrail,
              currentLevel: note.currentLevel,
              totalLevels: note.totalLevels,
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

  void _showRemarkDialog(BuildContext context, WidgetRef ref,
      {required bool isApprove}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isApprove ? 'Approve Note' : 'Reject Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove
                  ? 'This note will be forwarded to the next level.'
                  : 'This will stop the approval workflow.',
              style: const TextStyle(color: AppColors.txt2, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(color: AppColors.txt),
              decoration: InputDecoration(
                labelText: 'Remark *',
                hintText: isApprove
                    ? 'Enter your approval remark…'
                    : 'Enter rejection reason…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          isApprove
              ? GradientButton(
                  label: 'Approve',
                  small: true,
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    final ok = await ref
                        .read(noteFormProvider.notifier)
                        .approve(note.id, ctrl.text.trim());
                    if (ok && context.mounted) {
                      ref.invalidate(noteDetailProvider(note.id));
                    }
                  },
                )
              : GhostButton(
                  label: 'Reject',
                  danger: true,
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    final ok = await ref
                        .read(noteFormProvider.notifier)
                        .reject(note.id, ctrl.text.trim());
                    if (ok && context.mounted) {
                      ref.invalidate(noteDetailProvider(note.id));
                    }
                  },
                ),
        ],
      ),
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
          const Divider(height: 24, color: AppColors.line),
          _InfoRow('Objective in Detail', note.objectiveInDetail,
              multiLine: true),
          const SizedBox(height: 12),
          _InfoRow('Brief Note', note.briefNote, multiLine: true),
          const SizedBox(height: 12),
          _InfoRow('Expected Benefit', note.benefit, multiLine: true),
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
                style: const TextStyle(
                    color: AppColors.txt3,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppColors.txt, fontSize: 14, height: 1.6)),
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
                style: const TextStyle(
                    color: AppColors.txt3, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.txt,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Attachments Card ───────────────────────────────────────────────────────────
class _AttachmentsCard extends StatelessWidget {
  const _AttachmentsCard({required this.attachments});
  final List<NoteAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return VistarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Attachments'),
          const SizedBox(height: 16),
          if (attachments.isEmpty)
            const Text('No attachments',
                style: TextStyle(color: AppColors.txt3, fontSize: 13.5))
          else
            Column(
              children: attachments
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_file_rounded,
                                  size: 18, color: AppColors.txt3),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(a.fileName,
                                    style: const TextStyle(
                                        color: AppColors.txt2, fontSize: 13.5)),
                              ),
                              if (a.sizeBytes != null)
                                Text(
                                  '${(a.sizeBytes! / 1024).toStringAsFixed(1)} KB',
                                  style: const TextStyle(
                                      color: AppColors.txt3, fontSize: 12),
                                ),
                              const SizedBox(width: 8),
                              const Icon(Icons.download_rounded,
                                  size: 18, color: AppColors.txt3),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Approval Trail Card ────────────────────────────────────────────────────────
class _ApprovalTrailCard extends StatelessWidget {
  const _ApprovalTrailCard({
    required this.trail,
    required this.currentLevel,
    required this.totalLevels,
  });
  final List<ApprovalAction> trail;
  final int currentLevel;
  final int totalLevels;

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
            backgroundColor: AppColors.surface3,
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
                  const TextStyle(color: AppColors.txt3, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (trail.isEmpty)
            const Text('No approval actions yet.',
                style: TextStyle(color: AppColors.txt3, fontSize: 13.5))
          else
            Column(
              children: trail
                  .map((action) => _ApprovalStep(action: action))
                  .toList(),
            ),
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
    final color = isApproved ? AppColors.ok : AppColors.bad;
    final icon = isApproved
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
                    style: const TextStyle(
                        color: AppColors.txt, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                formatDateTime(action.actedAt),
                style: const TextStyle(
                    color: AppColors.txt3, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${action.remark}"',
            style: const TextStyle(
                color: AppColors.txt2,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
