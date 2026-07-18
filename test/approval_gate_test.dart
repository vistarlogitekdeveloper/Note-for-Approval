import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';
import 'package:note_approval/shared/models/user.dart';

/// The frontend approve/reject gate must agree with `canActAt()` in the API's
/// note.service.js, branch for branch. A button the server would refuse is as
/// wrong as a missing one, and both have shipped here before.
///
/// This mirrors the getter rather than importing it, because `_canApprove`
/// lives on a private widget State. The rule is duplicated deliberately and
/// the two must be changed together.
bool canApprove(Note note, User? user) {
  if (user == null || note.status != NoteStatus.pendingApproval) return false;

  if (note.hasCustomChain) {
    final mine = note.approverChain.where((a) => a.userId == user.id);
    if (mine.isNotEmpty) {
      return mine.any((a) => a.level == note.currentLevel);
    }
    return user.role.canAdmin;
  }

  if (user.role.canAdmin) return true;
  return user.role.canApprove && user.hierarchyLevel == note.currentLevel;
}

User _user(String id, UserRole role, {int? level}) =>
    User(id: id, name: id, email: '$id@x.com', role: role, hierarchyLevel: level);

NoteApprover _rung(int level, String userId) => NoteApprover(
      id: 'r$level',
      level: level,
      userId: userId,
      roleName: 'L$level',
      userName: userId,
      userEmail: '$userId@x.com',
    );

Note _note({
  required int currentLevel,
  List<NoteApprover> chain = const [],
  NoteStatus status = NoteStatus.pendingApproval,
}) =>
    Note(
      id: 'n1',
      noteNumber: 'NFA-2026-0001',
      purposeId: 'p1',
      purposeLabel: 'Purpose',
      objectiveInDetail: 'o',
      briefNote: 'b',
      benefit: 'x',
      costImpact: 'y',
      status: status,
      currentLevel: currentLevel,
      totalLevels: 3,
      initiatorId: 'init',
      initiatorName: 'Init',
      initiatorEmail: 'init@x.com',
      attachments: const [],
      approvalTrail: const [],
      approverChain: chain,
    );

void main() {
  final approver2 = _user('a2', UserRole.approver, level: 2);
  // Admins are pinned to a null hierarchy_level server-side. That null is what
  // silently hid the buttons on every chainless note in an earlier revision.
  final admin = _user('admin', UserRole.admin);
  final superAdmin = _user('su', UserRole.superAdmin);

  group('custom chain — the order must hold', () {
    // The reported bug: L1 approver2, L2 admin, L3 super admin.
    final chain = [_rung(1, 'a2'), _rung(2, 'admin'), _rung(3, 'su')];

    test('the named approver acts at their own level', () {
      expect(canApprove(_note(currentLevel: 1, chain: chain), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 2, chain: chain), admin), isTrue);
      expect(canApprove(_note(currentLevel: 3, chain: chain), superAdmin), isTrue);
    });

    test('a super admin named last cannot jump the queue', () {
      // This is the bug from the screenshot.
      expect(canApprove(_note(currentLevel: 1, chain: chain), superAdmin), isFalse);
      expect(canApprove(_note(currentLevel: 2, chain: chain), superAdmin), isFalse);
    });

    test('an admin named mid-chain cannot act early or late', () {
      expect(canApprove(_note(currentLevel: 1, chain: chain), admin), isFalse);
      expect(canApprove(_note(currentLevel: 3, chain: chain), admin), isFalse);
    });

    test('an approver cannot act again after their level has passed', () {
      expect(canApprove(_note(currentLevel: 2, chain: chain), approver2), isFalse);
    });

    test('an admin NOT on the chain keeps the override, to unstick a note', () {
      final outsider = _user('other-admin', UserRole.admin);
      expect(canApprove(_note(currentLevel: 1, chain: chain), outsider), isTrue);
    });

    test('a non-admin not on the chain gets nothing', () {
      final stranger = _user('stranger', UserRole.approver, level: 1);
      expect(canApprove(_note(currentLevel: 1, chain: chain), stranger), isFalse);
    });

    test('someone named at two levels may act at each', () {
      final twice = [_rung(1, 'a2'), _rung(2, 'a2')];
      expect(canApprove(_note(currentLevel: 1, chain: twice), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 2, chain: twice), approver2), isTrue);
    });
  });

  group('global route — no chain, must behave as it always did', () {
    test('the level holder acts at their level only', () {
      expect(canApprove(_note(currentLevel: 2), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 1), approver2), isFalse);
    });

    test('admins keep the override despite a null hierarchy level', () {
      // The regression this suite exists for: null == 1 is false, which hid
      // the buttons from every admin on every chainless note.
      expect(admin.hierarchyLevel, isNull);
      expect(canApprove(_note(currentLevel: 1), admin), isTrue);
      expect(canApprove(_note(currentLevel: 3), superAdmin), isTrue);
    });

    test('an initiator with no approval rights gets nothing', () {
      final initiator = _user('init', UserRole.initiator);
      expect(canApprove(_note(currentLevel: 1), initiator), isFalse);
    });
  });

  group('status gates everything', () {
    final chain = [_rung(1, 'a2')];

    test('nobody decides a draft, an approved, or a rejected note', () {
      for (final s in [NoteStatus.draft, NoteStatus.approved, NoteStatus.rejected]) {
        expect(canApprove(_note(currentLevel: 1, chain: chain, status: s), approver2),
            isFalse,
            reason: 'status $s must not be actionable');
        expect(canApprove(_note(currentLevel: 1, status: s), superAdmin), isFalse,
            reason: 'status $s must not be actionable even for a super admin');
      }
    });

    test('a signed-out user decides nothing', () {
      expect(canApprove(_note(currentLevel: 1), null), isFalse);
    });
  });
}
