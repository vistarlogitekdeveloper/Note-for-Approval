/// The two application roles (backend migration 090):
///   admin — full access, may act on any note.
///   user  — creates notes, and approves / rejects / reassigns the notes that
///           name them on a chain.
///
/// The getter names are kept from the old four-role model so call sites don't
/// all have to change: `canApprove` is now true for everyone (the real gate is
/// whether the note's chain names you at its current level), and `isInitiator`
/// is true for everyone (both roles raise notes).
enum UserRole {
  admin,
  user;

  bool get canAdmin => this == admin;
  bool get canApprove => true;
  bool get canManageUsers => this == admin;
  bool get isInitiator => true;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.user => 'User',
      };

  /// Tolerant of the pre-090 wire values so a cached token or an old response
  /// still resolves: initiator/approver -> user, superAdmin -> admin.
  factory UserRole.fromWire(String? s) => switch (s) {
        'admin' || 'superAdmin' => UserRole.admin,
        _ => UserRole.user,
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
        role: UserRole.fromWire(j['role'] as String?),
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
