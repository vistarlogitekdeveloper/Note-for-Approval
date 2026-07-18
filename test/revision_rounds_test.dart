import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';

/// A rejection returns the note to its initiator instead of killing it. They
/// revise, resubmit, and the walk restarts at level 1 — while every earlier
/// round stays in the trail.
///
/// These cover the two rules the UI depends on: who may edit a note in each
/// status, and how the trail splits into rounds.
ApprovalAction _act({
  required int revision,
  required int level,
  required bool approved,
  String remark = '',
}) =>
    ApprovalAction(
      id: 'r$revision-l$level',
      level: level,
      revision: revision,
      roleName: 'L$level',
      approverId: 'u$level',
      approverName: 'Approver $level',
      action: approved ? 'approved' : 'rejected',
      remark: remark,
    );

Note _note({
  required NoteStatus status,
  String initiatorId = 'me',
  int revision = 1,
  List<ApprovalAction> trail = const [],
}) =>
    Note(
      id: 'n1',
      noteNumber: 'NFA-2026-0002',
      purposeId: 'p1',
      purposeLabel: 'Purpose',
      objectiveInDetail: 'o',
      briefNote: 'b',
      benefit: 'x',
      costImpact: 'y',
      status: status,
      currentLevel: 1,
      totalLevels: 3,
      revision: revision,
      initiatorId: initiatorId,
      initiatorName: 'Me',
      initiatorEmail: 'me@x.com',
      attachments: const [],
      approvalTrail: trail,
    );

void main() {
  group('who may edit', () {
    test('the initiator may edit a draft', () {
      expect(_note(status: NoteStatus.draft).editableBy('me'), isTrue);
    });

    test('the initiator may edit a RETURNED note — the point of the change', () {
      expect(_note(status: NoteStatus.rejected).editableBy('me'), isTrue);
    });

    test('an in-flight note is frozen', () {
      expect(_note(status: NoteStatus.pendingApproval).editableBy('me'), isFalse);
    });

    test('an approved note is frozen', () {
      expect(_note(status: NoteStatus.approved).editableBy('me'), isFalse);
    });

    test('someone else cannot edit it, whatever the status', () {
      for (final s in [NoteStatus.draft, NoteStatus.rejected]) {
        expect(_note(status: s).editableBy('someone-else'), isFalse,
            reason: 'a non-initiator must never edit a $s note');
      }
    });

    test('a signed-out user cannot edit', () {
      expect(_note(status: NoteStatus.rejected).editableBy(null), isFalse);
    });

    test('isReturned marks exactly the rejected state', () {
      expect(_note(status: NoteStatus.rejected).isReturned, isTrue);
      expect(_note(status: NoteStatus.draft).isReturned, isFalse);
      expect(_note(status: NoteStatus.approved).isReturned, isFalse);
    });
  });

  group('trail grouped into rounds', () {
    // The scenario asked for: L1 approves, L2 rejects; after the revision
    // L1, L2 and L3 all approve.
    final trail = [
      _act(revision: 1, level: 1, approved: true, remark: 'ok'),
      _act(revision: 1, level: 2, approved: false, remark: 'cost unclear'),
      _act(revision: 2, level: 1, approved: true, remark: 'clearer'),
      _act(revision: 2, level: 2, approved: true, remark: 'justified'),
      _act(revision: 2, level: 3, approved: true, remark: 'signed off'),
    ];

    test('every decision from both rounds survives', () {
      final rounds = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound;
      expect(rounds.length, 2);
      expect(rounds.fold<int>(0, (n, r) => n + r.value.length), 5);
    });

    test('rounds come out oldest first, levels in order', () {
      final rounds = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound;
      expect(rounds[0].key, 1);
      expect(rounds[1].key, 2);
      expect(rounds[0].value.map((a) => a.level), [1, 2]);
      expect(rounds[1].value.map((a) => a.level), [1, 2, 3]);
    });

    test('round 1 records the approval AND the rejection', () {
      final r1 = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound[0]
          .value;
      expect(r1[0].isApproved, isTrue);
      expect(r1[1].isApproved, isFalse);
      expect(r1[1].remark, 'cost unclear');
    });

    test('order is imposed here, not assumed from the server', () {
      // The API has no guaranteed order for a nested include, so the model has
      // to sort. Feed it backwards and it must still come out right.
      final shuffled = trail.reversed.toList();
      final rounds = _note(
        status: NoteStatus.approved,
        revision: 2,
        trail: shuffled,
      ).trailByRound;
      expect(rounds.map((r) => r.key), [1, 2]);
      expect(rounds[1].value.map((a) => a.level), [1, 2, 3]);
    });

    test('a note that was never returned has a single round', () {
      final rounds = _note(
        status: NoteStatus.pendingApproval,
        trail: [_act(revision: 1, level: 1, approved: true)],
      ).trailByRound;
      expect(rounds.length, 1);
      expect(rounds.single.key, 1);
    });

    test('an untouched note has no rounds', () {
      expect(_note(status: NoteStatus.draft).trailByRound, isEmpty);
    });
  });

  group('parsing', () {
    test('revision defaults to 1 when the server omits it', () {
      // Rows written before rounds existed carry no revision.
      final a = ApprovalAction.fromJson({
        'id': 'x',
        'level': 2,
        'role_name': 'L2',
        'action': 'approved',
        'remark': 'fine',
      });
      expect(a.revision, 1);
    });

    test('revision is read when present', () {
      final a = ApprovalAction.fromJson({
        'id': 'x',
        'level': 1,
        'revision': 3,
        'role_name': 'L1',
        'action': 'rejected',
        'remark': 'no',
      });
      expect(a.revision, 3);
    });
  });
}
