import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';

/// `GET /approvals/my-decisions` answers "what have I done", which the
/// dashboard cannot: its cards count notes by CURRENT status, so a note you
/// rejected that was later revised and approved shows there as approved.
///
/// These pin the parsing and the outcome-drift flag that makes that
/// distinction visible.
void main() {
  Map<String, dynamic> row({
    String action = 'approved',
    int level = 2,
    int? revision,
    String noteStatus = 'approved',
    String remark = 'looks fine',
  }) =>
      {
        'id': 'a1',
        'level': level,
        if (revision != null) 'revision': revision,
        'role_name': 'L$level - Dept Head',
        'action': action,
        'remark': remark,
        'acted_at': '2026-07-18T10:55:00.000Z',
        'note': {
          'id': 'n1',
          'note_number': 'NFA-2026-0016',
          'objective_in_detail': 'buy three laptops',
          'status': noteStatus,
        },
      };

  group('parsing', () {
    test('reads the decision and the note it belongs to', () {
      final d = MyDecision.fromJson(row());
      expect(d.action, 'approved');
      expect(d.isApproved, isTrue);
      expect(d.level, 2);
      expect(d.roleName, 'L2 - Dept Head');
      expect(d.remark, 'looks fine');
      expect(d.noteNumber, 'NFA-2026-0016');
      expect(d.noteObjective, 'buy three laptops');
      expect(d.noteStatus, NoteStatus.approved);
      expect(d.actedAt, isNotNull);
    });

    test('revision defaults to 1 when absent', () {
      expect(MyDecision.fromJson(row()).revision, 1);
    });

    test('revision is read when present', () {
      expect(MyDecision.fromJson(row(revision: 2)).revision, 2);
    });

    test('a rejection parses as one', () {
      final d = MyDecision.fromJson(row(action: 'rejected', noteStatus: 'rejected'));
      expect(d.isApproved, isFalse);
    });

    test('survives a missing note object rather than throwing', () {
      final d = MyDecision.fromJson({
        'id': 'a1',
        'level': 1,
        'role_name': 'L1',
        'action': 'approved',
        'remark': '',
      });
      expect(d.noteNumber, '—');
      expect(d.noteStatus, NoteStatus.draft);
    });
  });

  group('outcome drift — where the note ended up vs what I decided', () {
    test('I approved and it is still approved: no drift', () {
      final d = MyDecision.fromJson(row(action: 'approved', noteStatus: 'approved'));
      expect(d.outcomeDiffers, isFalse);
    });

    test('I approved but a later level rejected it: drift', () {
      final d = MyDecision.fromJson(row(action: 'approved', noteStatus: 'rejected'));
      expect(d.outcomeDiffers, isTrue);
    });

    test('I rejected and it is still sitting rejected: no drift', () {
      final d = MyDecision.fromJson(row(action: 'rejected', noteStatus: 'rejected'));
      expect(d.outcomeDiffers, isFalse);
    });

    test('I rejected but it was revised and approved: drift', () {
      // The exact case the dashboard gets wrong — it would count this note
      // under "Approved" even though this user rejected it.
      final d = MyDecision.fromJson(row(action: 'rejected', noteStatus: 'approved'));
      expect(d.outcomeDiffers, isTrue);
    });
  });

  group('page tallies', () {
    test('lifetime totals come from meta, not the visible page', () {
      final page = MyDecisionPage.fromResult(
        [MyDecision.fromJson(row())], // one row on this page
        {'approved': 12, 'rejected': 3, 'total': 15},
      );
      expect(page.decisions.length, 1);
      expect(page.approved, 12);
      expect(page.rejected, 3);
      expect(page.total, 15);
    });

    test('falls back sanely when meta is absent', () {
      final page = MyDecisionPage.fromResult([MyDecision.fromJson(row())], null);
      expect(page.approved, 0);
      expect(page.rejected, 0);
      expect(page.total, 1);
    });

    test('an approver who has done nothing reads as all zeros', () {
      final page = MyDecisionPage.fromResult(const [], {'approved': 0, 'rejected': 0, 'total': 0});
      expect(page.decisions, isEmpty);
      expect(page.approved + page.rejected, 0);
    });
  });
}
