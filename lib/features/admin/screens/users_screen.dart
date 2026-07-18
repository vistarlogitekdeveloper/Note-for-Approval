import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/admin_repository.dart';

final usersAdminProvider = FutureProvider<List<User>>((ref) async {
  return ref.read(adminRepositoryProvider).getUsers();
});

/// The levels an approver can be assigned to. Needed by the user dialog, which
/// must send a `hierarchy_level` whenever the role is `approver`.
final hierarchyLevelsProvider = FutureProvider<List<HierarchyLevel>>((ref) async {
  return ref.read(adminRepositoryProvider).getHierarchy();
});

class UsersAdminScreen extends ConsumerWidget {
  const UsersAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersAdminProvider);

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
                  Text('Users',
                      style: GoogleFonts.bricolageGrotesque(
                        color: AppColors.txt,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  const Text('Manage user accounts and role assignments',
                      style: TextStyle(color: AppColors.txt3, fontSize: 14)),
                ],
              ),
              const Spacer(),
              GradientButton(
                label: 'Add User',
                icon: Icons.person_add_outlined,
                onPressed: () => _openUserDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: usersAsync.when(
              data: (users) => _UsersTable(users: users),
              loading: () => Column(
                children: List.generate(5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: ShimmerCard(height: 60),
                    )),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.bad)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Opens the add/edit user dialog and reports the result once it closes.
Future<void> _openUserDialog(
  BuildContext context,
  WidgetRef ref, [
  User? user,
]) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _UserDialog(user: user),
  );
  if (saved != true || !context.mounted) return;

  ref.invalidate(usersAdminProvider);
  AppFeedback.success(
    context,
    user == null ? 'User created.' : 'User updated.',
  );
}

/// Add / edit a user.
///
/// Own widget so controllers are disposed, the buttons disable while the call
/// is in flight, failures are shown inline instead of disappearing, and the
/// pop uses the DIALOG's context — popping with the screen's context resolves
/// to the ShellRoute's nested Navigator and closes the page instead.
class _UserDialog extends ConsumerStatefulWidget {
  const _UserDialog({this.user});
  final User? user;

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  late final _nameCtrl = TextEditingController(text: widget.user?.name);
  late final _emailCtrl = TextEditingController(text: widget.user?.email);
  final _passwordCtrl = TextEditingController();

  late UserRole _role = widget.user?.role ?? UserRole.initiator;
  late int? _level = widget.user?.hierarchyLevel;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return 'Full name is required.';
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'That does not look like a valid email address.';
    }
    // The server requires a password on create and enforces a 6-char minimum
    // on both paths. On edit it is optional and means "leave unchanged".
    final pw = _passwordCtrl.text;
    if (!_isEdit && pw.isEmpty) return 'A password is required.';
    if (pw.isNotEmpty && pw.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (_role == UserRole.approver && _level == null) {
      return 'An approver must be assigned a hierarchy level.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = ref.read(adminRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateUser(
          widget.user!.id,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          role: _role,
          password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
          hierarchyLevel: _level,
        );
      } else {
        await repo.createUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          role: _role,
          password: _passwordCtrl.text,
          hierarchyLevel: _level,
        );
      }
      if (!mounted) return;
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
    final levelsAsync = ref.watch(hierarchyLevelsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_isEdit ? 'Edit User' : 'Add User',
          style: const TextStyle(color: AppColors.txt, fontSize: 17)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                style: const TextStyle(color: AppColors.txt),
                decoration: const InputDecoration(labelText: 'Full Name *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailCtrl,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.txt),
                decoration: const InputDecoration(labelText: 'Email *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordCtrl,
                enabled: !_saving,
                obscureText: true,
                style: const TextStyle(color: AppColors.txt),
                decoration: InputDecoration(
                  labelText: _isEdit ? 'New Password' : 'Password *',
                  helperText: _isEdit
                      ? 'Leave blank to keep the current password'
                      : 'At least 6 characters',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                dropdownColor: AppColors.surface2,
                style: const TextStyle(color: AppColors.txt),
                decoration: const InputDecoration(labelText: 'Role *'),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                          _role = v ?? UserRole.initiator;
                          // Only approvers carry a level; the server pins it to
                          // null for everyone else.
                          if (_role != UserRole.approver) _level = null;
                        }),
              ),

              // Level is required for approvers and meaningless otherwise.
              if (_role == UserRole.approver) ...[
                const SizedBox(height: 14),
                levelsAsync.when(
                  loading: () => const ShimmerCard(height: 52),
                  error: (e, _) => Text(
                    'Could not load hierarchy levels: $e',
                    style: const TextStyle(color: AppColors.bad, fontSize: 12.5),
                  ),
                  data: (levels) {
                    final active = levels.where((l) => l.isActive).toList();
                    final value =
                        active.any((l) => l.level == _level) ? _level : null;
                    return DropdownButtonFormField<int>(
                      initialValue: value,
                      dropdownColor: AppColors.surface2,
                      style: const TextStyle(color: AppColors.txt),
                      decoration:
                          const InputDecoration(labelText: 'Hierarchy Level *'),
                      items: active
                          .map((l) => DropdownMenuItem(
                                value: l.level,
                                child: Text('L${l.level} — ${l.name}'),
                              ))
                          .toList(),
                      onChanged:
                          _saving ? null : (v) => setState(() => _level = v),
                    );
                  },
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 15, color: AppColors.bad),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.bad, fontSize: 12.5)),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: _saving
              ? 'Saving…'
              : (_isEdit ? 'Save Changes' : 'Create User'),
          small: true,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _UsersTable extends ConsumerWidget {
  const _UsersTable({required this.users});
  final List<User> users;

  /// Activate / deactivate. The server refuses to let you deactivate yourself,
  /// and says so — that message is worth showing verbatim rather than
  /// second-guessing it here.
  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, User u) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateUser(u.id, isActive: !u.isActive);
      if (!context.mounted) return;
      ref.invalidate(usersAdminProvider);
      AppFeedback.success(
        context,
        u.isActive ? '${u.name} deactivated.' : '${u.name} activated.',
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
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            // Self-sizing columns are intrinsic, not fixed — a role name or
            // status pill wider than the guess overflows, as the notes table
            // did. Name and email flex to absorb the slack.
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: IntrinsicColumnWidth(),
              3: IntrinsicColumnWidth(),
              4: IntrinsicColumnWidth(),
              5: IntrinsicColumnWidth(),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppColors.surface2),
                children: ['Name', 'Email', 'Role', 'Hierarchy Role', 'Status', '']
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: Text(
                            h.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.txt3,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              ...users.map((u) => _userRow(context, ref, u)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _userRow(BuildContext context, WidgetRef ref, User u) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              _avatar(u),
              const SizedBox(width: 10),
              Text(u.name,
                  style: const TextStyle(
                      color: AppColors.txt, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(u.email,
              style: const TextStyle(color: AppColors.txt2, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: _rolePill(u.role),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            u.hierarchyRoleName ?? '—',
            style: const TextStyle(color: AppColors.txt3, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: u.isActive
                  ? AppColors.ok.withValues(alpha: 0.12)
                  : AppColors.surface3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              u.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: u.isActive ? AppColors.ok : AppColors.txt3,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.txt3, size: 18),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'toggle',
                child: Text(u.isActive ? 'Deactivate' : 'Activate'),
              ),
            ],
            onSelected: (choice) {
              if (choice == 'edit') {
                _openUserDialog(context, ref, u);
              } else {
                _toggleActive(context, ref, u);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _avatar(User u) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: AppColors.ribbon,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(u.initials,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _rolePill(UserRole role) {
    final color = switch (role) {
      UserRole.superAdmin => AppColors.pink,
      UserRole.admin => AppColors.violet,
      UserRole.approver => AppColors.info,
      UserRole.initiator => AppColors.txt3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: TextStyle(
            color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
