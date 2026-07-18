import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

class CreateNoteScreen extends ConsumerStatefulWidget {
  const CreateNoteScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends ConsumerState<CreateNoteScreen> {
  final _formKey = GlobalKey<FormState>();

  // Field controllers
  final _objectiveDetailCtrl = TextEditingController();
  final _briefNoteCtrl = TextEditingController();
  final _benefitCtrl = TextEditingController();
  final _costImpactCtrl = TextEditingController();

  String? _selectedPurposeId;
  String? _selectedPurposeLabel;

  static const int _maxObjective = 500;
  static const int _maxBriefNote = 5000;

  /// Mirrors the server's allowlist in `middleware/upload.js`. Both the
  /// extension and the derived mime are checked there, so anything that gets
  /// past this list still has to survive the round trip.
  static const _allowedExtensions = ['pdf', 'docx', 'xlsx', 'png', 'jpg', 'jpeg'];
  static const _maxFileBytes = 20 * 1024 * 1024;
  static const _maxFilesPerUpload = 10;

  bool get _isEdit => widget.editId != null;

  /// The note being written to. Starts as [CreateNoteScreen.editId] and is
  /// filled in once a brand-new note is created, so a second "Save as Draft"
  /// updates the note the first one made instead of creating another.
  String? _noteId;

  // ── Edit-mode load state ────────────────────────────────────────────────
  bool _loading = false;
  String? _loadError;

  /// Non-null once an existing note has been read. The server only allows a
  /// draft to be edited, so a note that has moved on is shown read-only rather
  /// than letting the user type into a form that will 409 on save.
  NoteStatus? _status;

  /// Already on the server. Removed via the API, not from a local list.
  List<NoteAttachment> _existing = const [];

  /// The rejection that sent this note back, when it was returned. Shown above
  /// the form so the initiator can see what to fix.
  ApprovalAction? _lastRejection;

  /// Picked in the browser but not yet uploaded — a note must exist first.
  final List<AttachmentUpload> _staged = [];

  String? _attachmentError;

  /// This note's own approval chain, in order — index 0 approves first. Empty
  /// means the note follows the organisation-wide hierarchy instead, which is
  /// the default and what every note did before per-note chains existed.
  List<User> _chain = [];

  /// True once the chain has been touched in a way that must be sent. A note
  /// whose chain is untouched sends nothing, so an edit that only changes the
  /// text cannot accidentally clear a chain set elsewhere.
  bool _chainDirty = false;

  @override
  void initState() {
    super.initState();
    _noteId = widget.editId;
    if (_isEdit) _loadNote();
  }

  @override
  void dispose() {
    _objectiveDetailCtrl.dispose();
    _briefNoteCtrl.dispose();
    _benefitCtrl.dispose();
    _costImpactCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final note =
          await ref.read(notesRepositoryProvider).getNoteById(_noteId!);
      if (!mounted) return;
      setState(() {
        _selectedPurposeId = note.purposeId;
        _selectedPurposeLabel = note.purposeLabel;
        _objectiveDetailCtrl.text = note.objectiveInDetail;
        _briefNoteCtrl.text = note.briefNote;
        _benefitCtrl.text = note.benefit;
        _costImpactCtrl.text = note.costImpact;
        _existing = note.attachments;
        _status = note.status;
        // The most recent rejection is the one that sent it back; earlier
        // rounds are history and belong in the trail, not on the form.
        _lastRejection = note.approvalTrail
            .where((a) => !a.isApproved)
            .fold<ApprovalAction?>(
              null,
              (latest, a) => latest == null || a.revision >= latest.revision ? a : latest,
            );
        // Rebuild the chain as User rows so the picker and the saved note
        // speak the same type. A name/email that no longer resolves to a
        // selectable user still shows — it is what the note actually says.
        _chain = note.approverChain
            .map((a) => User(
                  id: a.userId,
                  name: a.userName,
                  email: a.userEmail,
                  role: UserRole.approver,
                  hierarchyRoleName: a.roleName,
                ))
            .toList();
        _chainDirty = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  /// A draft is still being written; a rejected note has been sent back to be
  /// revised. Both belong to the initiator. Anything else is in flight and the
  /// server would refuse the save.
  bool get _editable =>
      _status == null ||
      _status == NoteStatus.draft ||
      _status == NoteStatus.rejected;

  /// True when this is a revision of a note an approver sent back, which is a
  /// different thing from finishing a draft and should read that way.
  bool get _isRevision => _status == NoteStatus.rejected;

  Map<String, dynamic> _buildData() => {
        'purposeId': _selectedPurposeId,
        'purposeLabel': _selectedPurposeLabel,
        'objectiveInDetail': _objectiveDetailCtrl.text.trim(),
        'briefNote': _briefNoteCtrl.text.trim(),
        'benefit': _benefitCtrl.text.trim(),
        'costImpact': _costImpactCtrl.text.trim(),
        // Only sent when touched. An untouched chain must not be transmitted:
        // an empty list is the instruction to clear one, and sending it on
        // every text edit would silently wipe a chain the user still wants.
        if (_chainDirty)
          'approvers': [
            for (final u in _chain)
              ApproverChoice(userId: u.id, roleName: u.hierarchyRoleName),
          ],
      };

  // ── Attachments ─────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    setState(() => _attachmentError = null);

    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        // On web there are no file paths — bytes are the only way to read a
        // picked file, and without this they arrive null.
        withData: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _attachmentError = 'Could not open the file picker: $e');
      return;
    }
    if (result == null || !mounted) return; // dismissed

    final rejected = <String>[];
    final accepted = <AttachmentUpload>[];

    for (final file in result.files) {
      final ext = (file.extension ?? '').toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        rejected.add('${file.name} — .$ext is not an accepted type');
        continue;
      }
      if (file.size > _maxFileBytes) {
        rejected.add('${file.name} — ${formatBytes(file.size)} exceeds the 20 MB limit');
        continue;
      }
      final bytes = file.bytes;
      if (bytes == null && file.path == null) {
        rejected.add('${file.name} — could not be read');
        continue;
      }
      accepted.add(AttachmentUpload(
        fileName: file.name,
        bytes: bytes,
        path: bytes == null ? file.path : null,
      ));
    }

    final room = _maxFilesPerUpload - _staged.length;
    final fitting = accepted.take(room < 0 ? 0 : room).toList();
    if (fitting.length < accepted.length) {
      rejected.add(
        'Only $_maxFilesPerUpload files can be uploaded at once — '
        '${accepted.length - fitting.length} left out.',
      );
    }

    setState(() {
      _staged.addAll(fitting);
      _attachmentError = rejected.isEmpty ? null : rejected.join('\n');
    });
  }

  /// Opens the approver picker and appends the chosen person to the chain.
  /// Anyone already on the chain is excluded — the same person twice would
  /// mean approving their own earlier approval.
  Future<void> _addApprover() async {
    final chosen = await showDialog<User>(
      context: context,
      builder: (_) => _ApproverPickerDialog(
        excludeIds: _chain.map((u) => u.id).toSet(),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _chain.add(chosen);
      _chainDirty = true;
    });
  }

  Future<void> _removeExisting(NoteAttachment attachment) async {
    setState(() => _attachmentError = null);
    try {
      await ref
          .read(notesRepositoryProvider)
          .deleteAttachment(_noteId!, attachment.id);
      if (!mounted) return;
      setState(() => _existing =
          _existing.where((a) => a.id != attachment.id).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _attachmentError = 'Could not remove ${attachment.fileName}: $e');
    }
  }

  /// Run after any successful write. The staged list has to be emptied or the
  /// next save would upload the same files again, and the note lists are
  /// long-lived providers that would otherwise keep serving pre-save data.
  Future<void> _afterSave(Note note) async {
    _noteId = note.id;
    _staged.clear();
    ref.invalidate(myNotesProvider);
    ref.invalidate(filteredNotesProvider);
    ref.invalidate(recentNotesProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(noteDetailProvider(note.id));
    // Re-read so the attachment list reflects what the server actually stored.
    await _loadNote();
  }

  @override
  Widget build(BuildContext context) {
    final purposesAsync = ref.watch(purposesProvider);
    final formState = ref.watch(noteFormProvider);
    final notifier = ref.read(noteFormProvider.notifier);

    // Nothing on the form is meaningful until the note it edits has loaded.
    if (_loading && _status == null) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerCard(height: 44),
            SizedBox(height: 24),
            ShimmerCard(height: 420),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Banner(msg: _loadError!, isError: true),
            Row(children: [
              GhostButton(label: 'Back to notes', onPressed: () => context.go('/notes')),
              const SizedBox(width: 12),
              GhostButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: _loadNote),
            ]),
          ],
        ),
      );
    }

    return SingleChildScrollView(
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
                  Text(
                    _isEdit ? 'Edit Note' : 'Raise New Note',
                    style: GoogleFonts.bricolageGrotesque(
                      color: AppColors.txt,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    !_editable
                        ? 'This note is in flight and can no longer be changed'
                        : _isRevision
                            ? 'Address the feedback below, then submit again — '
                                'it restarts at level 1'
                            : 'Fill in all mandatory fields and submit for approval',
                    style: const TextStyle(color: AppColors.txt3, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error / success banners
          if (formState.error != null)
            _Banner(msg: formState.error!, isError: true),
          if (formState.success != null)
            _Banner(msg: formState.success!, isError: false),

          // The server refuses a PATCH on an in-flight note, so say it here
          // rather than let the user retype a form that will 409 on save.
          if (!_editable)
            _Banner(
              msg: 'This note is ${_status!.label.toLowerCase()} and is no longer '
                  'editable. Only a draft, or a note returned after rejection, '
                  'can be changed.',
              isError: true,
            ),

          // Revising blind would be pointless — show what the approver said.
          if (_isRevision && _lastRejection != null)
            _RejectionNotice(action: _lastRejection!),

          // Form card
          VistarCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Note Details'),
                  const SizedBox(height: 20),

                  // Purpose / Objective dropdown
                  purposesAsync.when(
                    data: (purposes) {
                      final active = purposes.where((p) => p.isActive).toList();
                      // A draft can point at a purpose that has since been
                      // deactivated. The dropdown asserts its value matches
                      // exactly one item, so an unlisted id would crash the
                      // form — fall back to unset and make the user re-pick.
                      final value = active.any((p) => p.id == _selectedPurposeId)
                          ? _selectedPurposeId
                          : null;
                      return DropdownButtonFormField<String>(
                        // The form is only built once the note has loaded, so
                        // the initial value already carries the saved purpose.
                        initialValue: value,
                        dropdownColor: AppColors.surface2,
                        style: const TextStyle(color: AppColors.txt, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Purpose / Objective *',
                          prefixIcon: const Icon(Icons.flag_outlined),
                          helperText: value == null && _selectedPurposeId != null
                              ? 'The previous purpose is no longer available — choose another.'
                              : null,
                        ),
                        items: active
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ))
                            .toList(),
                        validator: (v) =>
                            v == null ? 'Purpose is required' : null,
                        onChanged: !_editable
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedPurposeId = v;
                                  _selectedPurposeLabel =
                                      active.firstWhere((p) => p.id == v).name;
                                });
                              },
                      );
                    },
                    loading: () => const _FieldShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Objective in Detail (max 500 chars)
                  _CharLimitField(
                    controller: _objectiveDetailCtrl,
                    label: 'Objective in Detail *',
                    maxChars: _maxObjective,
                    enabled: _editable,
                    hint: 'Describe the objective in detail (max $_maxObjective characters)',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'This field is required';
                      if (v.length > _maxObjective) return 'Maximum $_maxObjective characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Brief Note (max 5000 chars)
                  _CharLimitField(
                    controller: _briefNoteCtrl,
                    label: 'Brief Note *',
                    maxChars: _maxBriefNote,
                    enabled: _editable,
                    hint: 'Provide a detailed brief note (max $_maxBriefNote characters)',
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Brief note is required';
                      if (v.length > _maxBriefNote) return 'Maximum $_maxBriefNote characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Benefit and Cost Impact in a row
                  LayoutBuilder(builder: (ctx, c) {
                    final twoCol = c.maxWidth > 700;
                    final benefitField = TextFormField(
                      controller: _benefitCtrl,
                      style: const TextStyle(color: AppColors.txt, fontSize: 14),
                      minLines: 3,
                      maxLines: null,
                      enabled: _editable,
                      decoration: const InputDecoration(
                        labelText: 'Expected Benefit *',
                        prefixIcon: Icon(Icons.trending_up_rounded),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Benefit is required' : null,
                    );
                    final costField = TextFormField(
                      controller: _costImpactCtrl,
                      style: const TextStyle(color: AppColors.txt, fontSize: 14),
                      minLines: 3,
                      maxLines: null,
                      enabled: _editable,
                      decoration: const InputDecoration(
                        labelText: 'Cost Impact *',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Cost impact is required' : null,
                    );
                    if (twoCol) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: benefitField),
                          const SizedBox(width: 16),
                          Expanded(child: costField),
                        ],
                      );
                    }
                    return Column(children: [
                      benefitField,
                      const SizedBox(height: 16),
                      costField,
                    ]);
                  }),
                  const SizedBox(height: 24),

                  // Approval chain
                  const SectionHeader('Approval Hierarchy'),
                  const SizedBox(height: 12),
                  _ApproverChainSection(
                    chain: _chain,
                    enabled: _editable && !formState.loading,
                    onAdd: _addApprover,
                    onRemove: (i) => setState(() {
                      _chain.removeAt(i);
                      _chainDirty = true;
                    }),
                    onMove: (from, to) => setState(() {
                      final u = _chain.removeAt(from);
                      _chain.insert(to, u);
                      _chainDirty = true;
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Attachments section
                  const SectionHeader('Attachments (Optional)'),
                  const SizedBox(height: 12),
                  _AttachmentsSection(
                    existing: _existing,
                    staged: _staged,
                    error: _attachmentError,
                    enabled: _editable && !formState.loading,
                    onPick: _pickFiles,
                    onRemoveStaged: (u) => setState(() => _staged.remove(u)),
                    onRemoveExisting: _removeExisting,
                  ),
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GhostButton(
                        label: 'Cancel',
                        onPressed: () => context.go('/notes'),
                      ),
                      const SizedBox(width: 12),
                      GhostButton(
                        label: formState.loading ? 'Saving…' : 'Save as Draft',
                        icon: Icons.save_outlined,
                        onPressed: !_editable || formState.loading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                final note = await notifier.saveDraft(
                                  _buildData(),
                                  editId: _noteId,
                                  attachments: List.of(_staged),
                                );
                                if (note != null && mounted) await _afterSave(note);
                              },
                      ),
                      const SizedBox(width: 12),
                      GradientButton(
                        label: _isRevision
                            ? 'Resubmit for Approval'
                            : 'Submit for Approval',
                        icon: Icons.send_rounded,
                        loading: formState.loading,
                        onPressed: !_editable
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                final note = await notifier.submit(
                                  _buildData(),
                                  editId: _noteId,
                                  attachments: List.of(_staged),
                                );
                                if (note == null || !mounted) return;
                                // Submitted notes leave draft, so the form is
                                // done with them — hand off to the detail view.
                                _staged.clear();
                                ref.invalidate(myNotesProvider);
                                ref.invalidate(filteredNotesProvider);
                                ref.invalidate(recentNotesProvider);
                                ref.invalidate(dashboardStatsProvider);
                                ref.invalidate(noteDetailProvider(note.id));
                                if (context.mounted) context.go('/notes/${note.id}');
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CharLimitField extends StatefulWidget {
  const _CharLimitField({
    required this.controller,
    required this.label,
    required this.maxChars,
    required this.hint,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxChars;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;

  /// Every one of these fields opens three lines tall and grows from there.
  static const _minLines = 3;

  @override
  State<_CharLimitField> createState() => _CharLimitFieldState();
}

class _CharLimitFieldState extends State<_CharLimitField> {
  int _chars = 0;

  @override
  void initState() {
    super.initState();
    _chars = widget.controller.text.length;
    widget.controller.addListener(() {
      setState(() => _chars = widget.controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final overLimit = _chars > widget.maxChars;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextFormField(
          controller: widget.controller,
          style: const TextStyle(color: AppColors.txt, fontSize: 14),
          // null maxLines is what makes the box grow instead of scroll.
          minLines: _CharLimitField._minLines,
          maxLines: null,
          enabled: widget.enabled,
          inputFormatters: [LengthLimitingTextInputFormatter(widget.maxChars)],
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            alignLabelWithHint: true,
          ),
          validator: widget.validator,
        ),
        const SizedBox(height: 4),
        Text(
          '$_chars / ${widget.maxChars}',
          style: TextStyle(
            color: overLimit ? AppColors.bad : AppColors.txt3,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

/// The note's own approval route, in order. An empty chain is a valid, normal
/// state — the note then follows the organisation-wide hierarchy — so this
/// says so plainly rather than presenting it as something unfinished.
class _ApproverChainSection extends StatelessWidget {
  const _ApproverChainSection({
    required this.chain,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onMove,
  });

  final List<User> chain;
  final bool enabled;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int from, int to) onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chain.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line2),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_tree_outlined, size: 18, color: AppColors.txt3),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This note will follow the standard company approval hierarchy. '
                    'Add approvers below to give it its own route instead.',
                    style: TextStyle(color: AppColors.txt2, fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ...chain.asMap().entries.map((e) {
            final i = e.key;
            final u = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line2),
                ),
                child: Row(
                  children: [
                    // Level badge — position in the list IS the level.
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.pink.withValues(alpha: 0.4)),
                      ),
                      child: Text('L${i + 1}',
                          style: const TextStyle(
                              color: AppColors.pink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              style: const TextStyle(
                                  color: AppColors.txt,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            u.hierarchyRoleName == null || u.hierarchyRoleName!.isEmpty
                                ? u.email
                                : '${u.email} · ${u.hierarchyRoleName}',
                            style: const TextStyle(color: AppColors.txt3, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (enabled) ...[
                      IconButton(
                        tooltip: 'Move up',
                        onPressed: i == 0 ? null : () => onMove(i, i - 1),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                        color: AppColors.txt3,
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        onPressed:
                            i == chain.length - 1 ? null : () => onMove(i, i + 1),
                        icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                        color: AppColors.txt3,
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onRemove(i),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: AppColors.txt3,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 4),
        GhostButton(
          label: chain.isEmpty ? 'Set a custom approval route' : 'Add approver',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: enabled ? onAdd : null,
        ),
      ],
    );
  }
}

/// Picks one person from the users who are actually able to approve. Sourced
/// from `/masters/approvers`, not the admin user list, so a plain initiator can
/// open it.
class _ApproverPickerDialog extends ConsumerStatefulWidget {
  const _ApproverPickerDialog({required this.excludeIds});
  final Set<String> excludeIds;

  @override
  ConsumerState<_ApproverPickerDialog> createState() =>
      _ApproverPickerDialogState();
}

class _ApproverPickerDialogState extends ConsumerState<_ApproverPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(selectableApproversProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Add approver',
          style: TextStyle(color: AppColors.txt, fontSize: 17)),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(color: AppColors.txt, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Could not load approvers.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.bad, fontSize: 13)),
                ),
                data: (users) {
                  final available = users
                      .where((u) => !widget.excludeIds.contains(u.id))
                      .where((u) =>
                          _query.isEmpty ||
                          u.name.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query))
                      .toList();

                  if (available.isEmpty) {
                    return const EmptyState(
                      message: 'No approvers match.',
                      icon: Icons.person_search_outlined,
                    );
                  }
                  return ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (_, i) {
                      final u = available[i];
                      return ListTile(
                        dense: true,
                        title: Text(u.name,
                            style: const TextStyle(
                                color: AppColors.txt, fontSize: 13.5)),
                        subtitle: Text(
                          u.hierarchyRoleName == null || u.hierarchyRoleName!.isEmpty
                              ? u.email
                              : '${u.email} · ${u.hierarchyRoleName}',
                          style: const TextStyle(
                              color: AppColors.txt3, fontSize: 12),
                        ),
                        onTap: () => Navigator.of(context).pop(u),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        GhostButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Shows two kinds of file: [existing] are already on the server and are
/// removed through the API, [staged] are picked but not yet uploaded — a note
/// has to exist before anything can be attached to it.
class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.existing,
    required this.staged,
    required this.enabled,
    required this.onPick,
    required this.onRemoveStaged,
    required this.onRemoveExisting,
    this.error,
  });

  final List<NoteAttachment> existing;
  final List<AttachmentUpload> staged;
  final bool enabled;
  final String? error;
  final VoidCallback onPick;
  final void Function(AttachmentUpload) onRemoveStaged;
  final void Function(NoteAttachment) onRemoveExisting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop zone
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: GestureDetector(
            onTap: enabled ? onPick : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line2),
              ),
              child: const Column(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      color: AppColors.txt3, size: 36),
                  SizedBox(height: 10),
                  Text('Click to browse files',
                      style: TextStyle(color: AppColors.txt2, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('PDF, DOCX, XLSX, PNG, JPG — max 20 MB each, 10 at a time',
                      style: TextStyle(color: AppColors.txt3, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: const TextStyle(color: AppColors.bad, fontSize: 12.5),
          ),
        ],

        if (existing.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Uploaded',
              style: TextStyle(
                  color: AppColors.txt3,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: existing
                .map((a) => _FileChip(
                      name: a.fileName,
                      detail: formatBytes(a.sizeBytes),
                      onRemove: enabled ? () => onRemoveExisting(a) : null,
                    ))
                .toList(),
          ),
        ],

        if (staged.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Will upload on save',
              style: TextStyle(
                  color: AppColors.txt3,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: staged
                .map((u) => _FileChip(
                      name: u.fileName,
                      detail: formatBytes(u.bytes?.length),
                      pending: true,
                      onRemove: enabled ? () => onRemoveStaged(u) : null,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({
    required this.name,
    this.detail,
    this.onRemove,
    this.pending = false,
  });

  final String name;
  final String? detail;
  final VoidCallback? onRemove;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pending ? AppColors.pink : AppColors.line2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pending ? Icons.schedule_rounded : Icons.attach_file_rounded,
              size: 14, color: pending ? AppColors.pink : AppColors.txt3),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.txt2, fontSize: 13)),
          ),
          if (detail != null) ...[
            const SizedBox(width: 6),
            Text(detail!,
                style: const TextStyle(color: AppColors.txt3, fontSize: 11.5)),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.txt3),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldShimmer extends StatelessWidget {
  const _FieldShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerCard(height: 52);
  }
}

/// What the approver said when they sent the note back.
class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({required this.action});
  final ApprovalAction action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bad.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bad.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.undo_rounded, color: AppColors.bad, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Returned by ${action.approverName}'
                  '${action.roleName.isEmpty ? '' : ' · ${action.roleName}'}',
                  style: const TextStyle(
                    color: AppColors.bad,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action.actedAt != null)
                Text(
                  formatDate(action.actedAt),
                  style:
                      const TextStyle(color: AppColors.txt3, fontSize: 11.5),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.remark,
            style: const TextStyle(color: AppColors.txt2, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.msg, required this.isError});
  final String msg;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.bad : AppColors.ok;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 13.5))),
        ],
      ),
    );
  }
}
