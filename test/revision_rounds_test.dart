import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';

/// An approver may send a note back to its initiator for revision: it moves to
/// its own `returned` status. They revise, resubmit, and the walk RESUMES at
/// the level that sent it back — while every earlier round stays in the trail.
/// A rejection, by contrast, is terminal.
///
/// These cover the two rules the UI depends on: who may edit a note in each
/// status, and how the trail splits into rounds.
ApprovalAction _act({
  required int revision,
  required int level,
  required String action,
  String remark = '',
}) =>
    ApprovalAction(
      id: 'r$revision-l$level',
      level: level,
      revision: revision,
      roleName: 'L$level',
      approverId: 'u$level',
      approverName: 'Approver $level',
      action: action,
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
      expect(_note(status: NoteStatus.returned).editableBy('me'), isTrue);
    });

    test('a rejected note is terminal and frozen', () {
      expect(_note(status: NoteStatus.rejected).editableBy('me'), isFalse);
    });

    test('an in-flight note is frozen', () {
      expect(_note(status: NoteStatus.pendingApproval).editableBy('me'), isFalse);
    });

    test('an approved note is frozen', () {
      expect(_note(status: NoteStatus.approved).editableBy('me'), isFalse);
    });

    test('someone else cannot edit it, whatever the status', () {
      for (final s in NoteStatus.values) {
        expect(_note(status: s).editableBy('someone-else'), isFalse,
            reason: 'a non-initiator must never edit a $s note');
      }
    });

    test('a signed-out user cannot edit', () {
      expect(_note(status: NoteStatus.returned).editableBy(null), isFalse);
    });

    test('isReturned marks exactly the returned state', () {
      for (final s in NoteStatus.values) {
        expect(_note(status: s).isReturned, s == NoteStatus.returned,
            reason: 'isReturned must be ${s == NoteStatus.returned} for $s');
      }
    });

    test('returned is not rejected', () {
      expect(_note(status: NoteStatus.returned).isRejected, isFalse);
      expect(_note(status: NoteStatus.rejected).isRejected, isTrue);
    });
  });

  group('trail grouped into rounds', () {
    // The scenario: L1 approves, L2 sends it back; after the revision the walk
    // resumes at L2 (L1's approval stands), and L2 and L3 approve.
    final trail = [
      _act(revision: 1, level: 1, action: 'approved', remark: 'ok'),
      _act(revision: 1, level: 2, action: 'reassigned', remark: 'cost unclear'),
      _act(revision: 2, level: 2, action: 'approved', remark: 'justified'),
      _act(revision: 2, level: 3, action: 'approved', remark: 'signed off'),
    ];

    test('every decision from both rounds survives', () {
      final rounds = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound;
      expect(rounds.length, 2);
      expect(rounds.fold<int>(0, (n, r) => n + r.value.length), 4);
    });

    test('rounds come out oldest first, levels in order', () {
      final rounds = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound;
      expect(rounds[0].key, 1);
      expect(rounds[1].key, 2);
      expect(rounds[0].value.map((a) => a.level), [1, 2]);
      expect(rounds[1].value.map((a) => a.level), [2, 3]);
    });

    test('round 1 records the approval AND the send-back', () {
      final r1 = _note(status: NoteStatus.approved, revision: 2, trail: trail)
          .trailByRound[0]
          .value;
      expect(r1[0].isApproved, isTrue);
      expect(r1[1].isApproved, isFalse);
      expect(r1[1].isReassigned, isTrue);
      expect(r1[1].isRejected, isFalse);
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
      expect(rounds[0].value.map((a) => a.level), [1, 2]);
      expect(rounds[1].value.map((a) => a.level), [2, 3]);
    });

    test('a note that was never returned has a single round', () {
      final rounds = _note(
        status: NoteStatus.pendingApproval,
        trail: [_act(revision: 1, level: 1, action: 'approved')],
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
