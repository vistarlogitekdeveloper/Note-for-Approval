import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../shared/widgets/gradient_button.dart';

// ── Mock provider (replace with real API) ────────────────────────────────────
final usersAdminProvider = FutureProvider<List<User>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return [
    User(id: '1', name: 'Arjun Sharma', email: 'arjun@vistar.com',
        role: UserRole.initiator, isActive: true),
    User(id: '2', name: 'Priya Mehta', email: 'priya@vistar.com',
        role: UserRole.approver, hierarchyLevel: 1,
        hierarchyRoleName: 'Department Head', isActive: true),
    User(id: '3', name: 'Rohit Verma', email: 'rohit@vistar.com',
        role: UserRole.approver, hierarchyLevel: 2,
        hierarchyRoleName: 'General Manager', isActive: true),
    User(id: '4', name: 'Sita Nair', email: 'sita@vistar.com',
        role: UserRole.admin, isActive: true),
    User(id: '5', name: 'Kiran Patel', email: 'kiran@vistar.com',
        role: UserRole.initiator, isActive: false),
  ];
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
                onPressed: () => _showUserDialog(context),
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

  void _showUserDialog(BuildContext context, [User? user]) {
    final nameCtrl = TextEditingController(text: user?.name);
    final emailCtrl = TextEditingController(text: user?.email);
    UserRole? selectedRole = user?.role ?? UserRole.initiator;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(user == null ? 'Add User' : 'Edit User'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.txt),
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: AppColors.txt),
                  decoration: const InputDecoration(labelText: 'Email *'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  dropdownColor: AppColors.surface2,
                  style: const TextStyle(color: AppColors.txt),
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedRole = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            GradientButton(
              label: user == null ? 'Create User' : 'Save Changes',
              small: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  const _UsersTable({required this.users});
  final List<User> users;

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
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FixedColumnWidth(130),
              3: FixedColumnWidth(180),
              4: FixedColumnWidth(90),
              5: FixedColumnWidth(80),
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
              ...users.map((u) => _userRow(context, u)),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _userRow(BuildContext context, User u) {
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
                  ? AppColors.ok.withOpacity(0.12)
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
            onSelected: (_) {},
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
        color: color.withOpacity(0.12),
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
