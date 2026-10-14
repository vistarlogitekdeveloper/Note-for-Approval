import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';
import 'package:note_approval/shared/models/user.dart';

/// The frontend approve/reject gate must agree with `canActAt()` in the API's
/// note.service.js, branch for branch. A button the server would refuse is as
/// wrong as a missing one, and both have shipped here before.
///
/// This mirrors the getter rather than importing it, because `_canApprove`
/// lives on a private widget (note_detail_screen.dart). The rule is
/// duplicated deliberately and the two must be changed together.
///
/// The rule is STRICT: only the user the note names at its CURRENT level may
/// act. Role plays no part — there is no admin override, on a custom chain or
/// on the global route.
bool canApprove(Note note, User? user) {
  if (user == null || note.status != NoteStatus.pendingApproval) return false;

  if (note.hasCustomChain) {
    return note.approverChain
        .any((a) => a.level == note.currentLevel && a.userId == user.id);
  }

  return user.hierarchyLevel == note.currentLevel;
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
  final approver2 = _user('a2', UserRole.user, level: 2);
  // Admins are pinned to a null hierarchy_level server-side, so on the global
  // route an admin holds no level — and, with no override, decides nothing.
  final admin = _user('admin', UserRole.admin);
  final admin2 = _user('su', UserRole.admin);

  group('custom chain — the order must hold', () {
    // The reported bug: L1 approver2, L2 admin, L3 another admin.
    final chain = [_rung(1, 'a2'), _rung(2, 'admin'), _rung(3, 'su')];

    test('the named approver acts at their own level', () {
      expect(canApprove(_note(currentLevel: 1, chain: chain), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 2, chain: chain), admin), isTrue);
      expect(canApprove(_note(currentLevel: 3, chain: chain), admin2), isTrue);
    });

    test('an admin named last cannot jump the queue', () {
      // This is the bug from the screenshot.
      expect(canApprove(_note(currentLevel: 1, chain: chain), admin2), isFalse);
      expect(canApprove(_note(currentLevel: 2, chain: chain), admin2), isFalse);
    });

    test('an admin named mid-chain cannot act early or late', () {
      expect(canApprove(_note(currentLevel: 1, chain: chain), admin), isFalse);
      expect(canApprove(_note(currentLevel: 3, chain: chain), admin), isFalse);
    });

    test('an approver cannot act again after their level has passed', () {
      expect(canApprove(_note(currentLevel: 2, chain: chain), approver2), isFalse);
    });

    test('an admin NOT on the chain gets nothing — there is no override', () {
      final outsider = _user('other-admin', UserRole.admin);
      for (final level in [1, 2, 3]) {
        expect(canApprove(_note(currentLevel: level, chain: chain), outsider),
            isFalse,
            reason: 'an off-chain admin must not act at level $level');
      }
    });

    test('a user not on the chain gets nothing, even holding the level', () {
      // The chain replaces the global hierarchy outright: a matching
      // hierarchy_level is irrelevant on a note with its own chain.
      final stranger = _user('stranger', UserRole.user, level: 1);
      expect(canApprove(_note(currentLevel: 1, chain: chain), stranger), isFalse);
    });

    test('someone named at two levels may act at each', () {
      final twice = [_rung(1, 'a2'), _rung(2, 'a2')];
      expect(canApprove(_note(currentLevel: 1, chain: twice), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 2, chain: twice), approver2), isTrue);
    });
  });

  group('global route — no chain, the level holder only', () {
    test('the level holder acts at their level only', () {
      expect(canApprove(_note(currentLevel: 2), approver2), isTrue);
      expect(canApprove(_note(currentLevel: 1), approver2), isFalse);
    });

    test('admins get no override on the global route either', () {
      expect(admin.hierarchyLevel, isNull);
      expect(canApprove(_note(currentLevel: 1), admin), isFalse);
      expect(canApprove(_note(currentLevel: 3), admin2), isFalse);
    });

    test('the level decides, not the role', () {
      final levelledAdmin = _user('la', UserRole.admin, level: 3);
      expect(canApprove(_note(currentLevel: 3), levelledAdmin), isTrue);
      expect(canApprove(_note(currentLevel: 2), levelledAdmin), isFalse);
    });

    test('a user holding no hierarchy level gets nothing', () {
      final creator = _user('init', UserRole.user);
      expect(canApprove(_note(currentLevel: 1), creator), isFalse);
    });
  });

  group('status gates everything', () {
    final chain = [_rung(1, 'a2')];

    test('nobody decides a draft, returned, approved, or rejected note', () {
      for (final s in [
        NoteStatus.draft,
        NoteStatus.returned,
        NoteStatus.approved,
        NoteStatus.rejected,
      ]) {
        expect(canApprove(_note(currentLevel: 1, chain: chain, status: s), approver2),
            isFalse,
            reason: 'status $s must not be actionable');
        expect(canApprove(_note(currentLevel: 2, status: s), approver2), isFalse,
            reason: 'status $s must not be actionable on the global route');
      }
    });

    test('a signed-out user decides nothing', () {
      expect(canApprove(_note(currentLevel: 1), null), isFalse);
    });
  });
}
