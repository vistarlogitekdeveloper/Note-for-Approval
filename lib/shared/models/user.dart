/// Approval roles in the hierarchy
enum UserRole {
  initiator,
  approver,
  admin,
  superAdmin;

  bool get canAdmin => this == admin || this == superAdmin;
  bool get canApprove => this == approver || this == admin || this == superAdmin;
  bool get canManageUsers => this == admin || this == superAdmin;
  bool get isInitiator => this == initiator;

  String get label => switch (this) {
        UserRole.initiator => 'Initiator',
        UserRole.approver => 'Approver',
        UserRole.admin => 'Admin',
        UserRole.superAdmin => 'Super Admin',
      };
}

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int? hierarchyLevel; // approvers only; server forces null for others
  final String? hierarchyRoleName; // e.g. "L1 - Section Head"
  final bool isActive;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.hierarchyLevel,
    this.hierarchyRoleName,
    this.isActive = true,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == j['role'],
          orElse: () => UserRole.initiator,
        ),
        hierarchyLevel: (j['hierarchy_level'] as num?)?.toInt(),
        hierarchyRoleName: j['hierarchy_role_name'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'hierarchy_level': hierarchyLevel,
        'hierarchy_role_name': hierarchyRoleName,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
