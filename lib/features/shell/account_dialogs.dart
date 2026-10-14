import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/user.dart';
import '../auth/data/auth_repository.dart';

/// The signed-in user's own details, read-only. Accounts are managed by an
/// administrator, so there is nothing to edit here.
Future<void> showProfileDialog(BuildContext context, User user) {
  Widget row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(color: context.c.txt3, fontSize: 13)),
            ),
            Expanded(
              child: SelectableText(value,
                  style: TextStyle(color: context.c.txt, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.c.surface,
      title: Text('Profile', style: TextStyle(color: context.c.txt, fontSize: 17)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row('Name', user.name),
            row('Email', user.email),
            row('Role', user.role.label),
            if (user.hierarchyRoleName != null && user.hierarchyRoleName!.isNotEmpty)
              row('Approval level', user.hierarchyRoleName!),
            const SizedBox(height: 8),
            Text(
              'To change your name or email, contact your administrator.',
              style: TextStyle(color: context.c.txt3, fontSize: 12.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

/// Change the signed-in user's password. Returns true once it has changed.
///
/// The server revokes every session of this account on a change, so the
/// caller signs the user out afterwards rather than leaving a session that
/// stops working at its next token refresh.
Future<bool> showChangePasswordDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ChangePasswordDialog(),
  );
  return changed ?? false;
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// The server's minimum (schemas.js PASSWORD_MIN).
  static const _minLength = 6;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ApiException
            ? (e.isNetwork ? 'Cannot reach the server. Please try again.' : e.message)
            : 'Could not change the password. Please try again.';
      });
    }
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.c.surface,
      title: Text('Change password', style: TextStyle(color: context.c.txt, fontSize: 17)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                autofocus: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.password],
                decoration: _field('Current password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _field('New password'),
                validator: (v) {
                  if (v == null || v.length < _minLength) {
                    return 'Use at least $_minLength characters';
                  }
                  if (v == _current.text) return 'Choose a password different from the current one';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                enabled: !_busy,
                decoration: _field('Confirm new password'),
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                validator: (v) => v != _next.text ? 'The passwords do not match' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'You will be signed out everywhere, including here, and can sign in again with the new password.',
                style: TextStyle(color: context.c.txt3, fontSize: 12.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 15, color: context.c.bad),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: context.c.bad, fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Changing…' : 'Change password'),
        ),
      ],
    );
  }
}
