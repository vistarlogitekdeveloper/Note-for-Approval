import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/notes_provider.dart';
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

  @override
  void dispose() {
    _objectiveDetailCtrl.dispose();
    _briefNoteCtrl.dispose();
    _benefitCtrl.dispose();
    _costImpactCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildData() => {
        'purposeId': _selectedPurposeId,
        'purposeLabel': _selectedPurposeLabel,
        'objectiveInDetail': _objectiveDetailCtrl.text.trim(),
        'briefNote': _briefNoteCtrl.text.trim(),
        'benefit': _benefitCtrl.text.trim(),
        'costImpact': _costImpactCtrl.text.trim(),
      };

  @override
  Widget build(BuildContext context) {
    final purposesAsync = ref.watch(purposesProvider);
    final formState = ref.watch(noteFormProvider);
    final notifier = ref.read(noteFormProvider.notifier);

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
                    widget.editId != null ? 'Edit Note' : 'Raise New Note',
                    style: GoogleFonts.bricolageGrotesque(
                      color: AppColors.txt,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Fill in all mandatory fields and submit for approval',
                    style: TextStyle(color: AppColors.txt3, fontSize: 14),
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
                    data: (purposes) => DropdownButtonFormField<String>(
                      value: _selectedPurposeId,
                      dropdownColor: AppColors.surface2,
                      style: const TextStyle(color: AppColors.txt, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Purpose / Objective *',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: purposes
                          .where((p) => p.isActive)
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ))
                          .toList(),
                      validator: (v) =>
                          v == null ? 'Purpose is required' : null,
                      onChanged: (v) {
                        setState(() {
                          _selectedPurposeId = v;
                          _selectedPurposeLabel = purposes
                              .firstWhere((p) => p.id == v)
                              .name;
                        });
                      },
                    ),
                    loading: () => const _FieldShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Objective in Detail (max 500 chars)
                  _CharLimitField(
                    controller: _objectiveDetailCtrl,
                    label: 'Objective in Detail *',
                    maxChars: _maxObjective,
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
                    hint: 'Provide a detailed brief note (max $_maxBriefNote characters)',
                    maxLines: 8,
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
                      maxLines: 3,
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
                      maxLines: 3,
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

                  // Attachments section
                  const SectionHeader('Attachments (Optional)'),
                  const SizedBox(height: 12),
                  _AttachmentsSection(),
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
                        onPressed: formState.loading
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) return;
                                await notifier.saveDraft(
                                  _buildData(),
                                  editId: widget.editId,
                                );
                              },
                      ),
                      const SizedBox(width: 12),
                      GradientButton(
                        label: 'Submit for Approval',
                        icon: Icons.send_rounded,
                        loading: formState.loading,
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final note = await notifier.submit(
                            _buildData(),
                            editId: widget.editId,
                          );
                          if (note != null && context.mounted) {
                            context.go('/notes/${note.id}');
                          }
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
    this.maxLines = 3,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxChars;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

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
          maxLines: widget.maxLines,
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

class _AttachmentsSection extends StatefulWidget {
  @override
  State<_AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<_AttachmentsSection> {
  final List<String> _fileNames = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drop zone
        GestureDetector(
          onTap: () {
            // file_picker integration point
            setState(() {
              _fileNames.add('example_document.pdf');
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.line2,
                style: BorderStyle.solid,
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    color: AppColors.txt3, size: 36),
                SizedBox(height: 10),
                Text('Click to browse files',
                    style: TextStyle(color: AppColors.txt2, fontSize: 14)),
                SizedBox(height: 4),
                Text('PDF, DOC, XLS, PNG, JPG — max 20 MB each',
                    style: TextStyle(color: AppColors.txt3, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_fileNames.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _fileNames
                .map((f) => _FileChip(
                      name: f,
                      onRemove: () => setState(() => _fileNames.remove(f)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.txt3),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(color: AppColors.txt2, fontSize: 13)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppColors.txt3),
          ),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
