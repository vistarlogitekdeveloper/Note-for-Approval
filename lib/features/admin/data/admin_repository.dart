import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/models/user.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.read(apiClientProvider)),
);

/// Admin-only reads and writes. Everything here needs `admin` or `superAdmin`;
/// the server answers 403 `FORBIDDEN_ROLE` otherwise.
class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  static const _listLimit = 100;

  Future<List<User>> getUsers({
    String? role,
    bool? isActive,
    String? search,
  }) async {
    final res = await _api.get(ApiEndpoints.users, params: {
      'role': role,
      'is_active': isActive,
      'search': search,
      'limit': _listLimit,
    });
    return res.asList.map(User.fromJson).toList();
  }

  /// [hierarchyLevel] is required by the server when [role] is `approver`, and
  /// is forced to null for every other role — sending one anyway is harmless.
  ///
  /// [password] has a 6-character minimum server-side.
  Future<User> createUser({
    required String name,
    required String email,
    required UserRole role,
    required String password,
    int? hierarchyLevel,
  }) async {
    final res = await _api.post(ApiEndpoints.users, data: {
      'name': name,
      'email': email,
      'role': role.name,
      'password': password,
      // hierarchy_level is dormant under the two-role model — a note names its
      // own approvers by id — so it is no longer sent.
    });
    return User.fromJson(res.asMap);
  }

  /// Only the fields passed are sent — the server patches what it receives.
  /// It refuses to let you deactivate or re-role yourself.
  Future<User> updateUser(
    String id, {
    String? name,
    String? email,
    UserRole? role,
    String? password,
    int? hierarchyLevel,
    bool? isActive,
  }) async {
    final res = await _api.patch(ApiEndpoints.userById(id), data: {
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (role != null) 'role': role.name,
      if (password != null && password.isNotEmpty) 'password': password,
      if (isActive != null) 'is_active': isActive,
    });
    return User.fromJson(res.asMap);
  }

  /// The approval levels users can be assigned to. Read-only through the API —
  /// levels cannot be created, deleted, or reordered.
  Future<List<HierarchyLevel>> getHierarchy() async {
    final res = await _api.get(ApiEndpoints.hierarchy);
    return res.asList.map(HierarchyLevel.fromJson).toList();
  }
}

/// A rung of the organisation-wide hierarchy, as the admin API reports it.
class HierarchyLevel {
  const HierarchyLevel({
    required this.id,
    required this.level,
    required this.name,
    this.isActive = true,
    this.approverCount = 0,
  });

  final String id;
  final int level;
  final String name;
  final bool isActive;

  /// Injected by the controller, not stored. A level with no approvers stalls
  /// every note that reaches it.
  final int approverCount;

  factory HierarchyLevel.fromJson(Map<String, dynamic> j) => HierarchyLevel(
        id: j['id'] as String,
        level: (j['level'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
        approverCount: (j['approver_count'] as num?)?.toInt() ?? 0,
      );
}
