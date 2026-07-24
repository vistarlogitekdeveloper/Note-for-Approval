import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/notes/data/notes_repository.dart';
import '../../../features/notes/models/note.dart';
import '../../../features/notes/providers/notes_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

/// Admin view of the purpose list, so it includes deactivated rows — the note
/// form's [purposesProvider] deliberately shows only active ones.
final purposesMasterProvider = FutureProvider<List<PurposeMaster>>((ref) async {
  return ref.read(notesRepositoryProvider).getPurposes(includeInactive: true);
});

class MastersScreen extends ConsumerWidget {
  const MastersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purposesAsync = ref.watch(purposesMasterProvider);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Purpose Masters',
                      style: GoogleFonts.bricolageGrotesque(
                        color: context.c.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  Text('Manage Purpose/Objective dropdown values',
                      style: TextStyle(color: context.c.txt3, fontSize: 14)),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Add Purpose',
                icon: Icons.add_rounded,
                onPressed: () => _openPurposeDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: purposesAsync.when(
              data: (items) => _PurposesList(items: items),
              loading: () => ListView(
                children: List.generate(8,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: ShimmerCard(height: 56),
                    )),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: TextStyle(color: context.c.bad)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Opens the add/edit dialog and reports the outcome once it closes.
///
/// The dialog reports its own failures inline (so the user can correct and
/// retry without retyping); success is announced out here, against the screen
/// that outlives it.
Future<void> _openPurposeDialog(
  BuildContext context,
  WidgetRef ref, [
  PurposeMaster? item,
]) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _PurposeDialog(item: item),
  );
  if (saved != true || !context.mounted) return;

  ref.invalidate(purposesMasterProvider);
  // The note form reads its own active-only list; it would otherwise keep
  // offering a stale set of purposes.
  ref.invalidate(purposesProvider);
  AppFeedback.success(
    context,
    item == null ? 'Purpose added.' : 'Purpose updated.',
  );
}

/// Add / edit a purpose.
///
/// Its own widget rather than an inline builder so the controller is disposed,
/// the in-flight state can disable the buttons, and — the bug this replaces —
/// the pop uses the DIALOG's context. `showDialog` mounts on the root
/// Navigator while these screens sit inside a go_router ShellRoute's nested
/// one, so popping with the screen's context closed the page and left the
/// dialog on screen.
class _PurposeDialog extends ConsumerStatefulWidget {
  const _PurposeDialog({this.item});
  final PurposeMaster? item;

  @override
  ConsumerState<_PurposeDialog> createState() => _PurposeDialogState();
}

class _PurposeDialogState extends ConsumerState<_PurposeDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.item?.name);
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Purpose name is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(notesRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updatePurpose(widget.item!.id, name: name);
      } else {
        await repo.createPurpose(name);
      }
      if (!mounted) return;
      // Pop first, then report: the SnackBar belongs to the screen underneath,
      // which outlives this dialog.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.c.surface,
      title: Text(_isEdit ? 'Edit Purpose' : 'Add Purpose',
          style: TextStyle(color: context.c.txt, fontSize: 17)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              enabled: !_saving,
              style: TextStyle(color: context.c.txt),
              decoration: const InputDecoration(labelText: 'Purpose Name *'),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: context.c.bad, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: _saving ? 'Saving…' : (_isEdit ? 'Save' : 'Add'),
          small: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _PurposesList extends ConsumerWidget {
  const _PurposesList({required this.items});
  final List<PurposeMaster> items;

  /// Flips a purpose active/inactive. Deactivating is how a purpose is retired
  /// without breaking notes that already reference it.
  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    PurposeMaster item,
    bool value,
  ) async {
    try {
      await ref
          .read(notesRepositoryProvider)
          .updatePurpose(item.id, isActive: value);
      if (!context.mounted) return;
      ref.invalidate(purposesMasterProvider);
      ref.invalidate(purposesProvider);
      AppFeedback.success(
        context,
        value ? '"${item.name}" is active again.' : '"${item.name}" deactivated.',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.c.line),
        borderRadius: BorderRadius.circular(16),
        color: context.c.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              color: context.c.surface2,
              child: const Row(
                children: [
                  Expanded(child: _TH('Purpose Name')),
                  SizedBox(width: 100, child: _TH('Status')),
                  SizedBox(width: 80, child: _TH('')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: context.c.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Text(item.name,
                                style: TextStyle(
                                    color: context.c.txt, fontSize: 14)),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Switch(
                              value: item.isActive,
                              onChanged: (v) => _toggle(context, ref, item, v),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: IconButton(
                              tooltip: 'Edit',
                              icon: Icon(Icons.edit_outlined,
                                  size: 18, color: context.c.txt3),
                              onPressed: () =>
                                  _openPurposeDialog(context, ref, item),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.c.txt3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
