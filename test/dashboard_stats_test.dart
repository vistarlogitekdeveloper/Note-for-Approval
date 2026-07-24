import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';

void main() {
  group('DashboardStats.fromJson', () {
    test('parses both scopes from the new response shape', () {
      // Mirrors the real backend payload for an admin (verified live).
      final stats = DashboardStats.fromJson({
        'total': 18,
        'draft': 2,
        'pendingApproval': 9,
        'approved': 4,
        'rejected': 2,
        'returned': 1,
        'mine': {
          'total': 10,
          'draft': 0,
          'pendingApproval': 5,
          'approved': 3,
          'rejected': 1,
          'returned': 1,
        },
        'myPendingApprovals': 0,
        'raisedByMe': 10,
        'isAdmin': true,
        'scope': 'all',
      });

      // All scope.
      expect(stats.all.total, 18);
      expect(stats.all.draft, 2);
      expect(stats.all.pending, 9); // pendingApproval -> pending
      expect(stats.all.approved, 4);
      expect(stats.all.rejected, 2);
      expect(stats.all.returned, 1);

      // Mine scope.
      expect(stats.mine.total, 10);
      expect(stats.mine.pending, 5);
      expect(stats.mine.approved, 3);
      expect(stats.mine.rejected, 1);
      expect(stats.mine.draft, 0);
      expect(stats.mine.returned, 1);

      expect(stats.isAdmin, isTrue);
      expect(stats.hasMineBreakdown, isTrue);
      expect(stats.pendingMyAction, 0);

      // scoped() picks the right breakdown.
      expect(stats.scoped(false).total, 18); // all
      expect(stats.scoped(true).total, 10); // mine

      // A scope's statuses must sum to its total — the invariant the KPI cards
      // rely on so "Total" always reconciles with the tiles beneath it. Since a
      // Returned card exists, `returned` is part of that sum (previously it was
      // silently dropped and Total undercounted the list).
      final a = stats.all;
      expect(a.draft + a.pending + a.returned + a.approved + a.rejected,
          a.total);
      final m = stats.mine;
      expect(m.draft + m.pending + m.returned + m.approved + m.rejected,
          m.total);
    });

    test('falls back to the visible scope when the server omits `mine`', () {
      // An older backend that has not deployed the split yet.
      final stats = DashboardStats.fromJson({
        'total': 7,
        'draft': 0,
        'pendingApproval': 5,
        'approved': 2,
        'rejected': 0,
        'myPendingApprovals': 1,
        'scope': 'visible-to-me',
      });

      expect(stats.hasMineBreakdown, isFalse);
      // mine mirrors all, so no card renders a misleading zero.
      expect(stats.mine.total, stats.all.total);
      expect(stats.scoped(true).total, stats.scoped(false).total);
      expect(stats.isAdmin, isFalse);
    });

    test('backward-compatible flat getters read the visible scope', () {
      final stats = DashboardStats.fromJson({
        'total': 17,
        'draft': 2,
        'pendingApproval': 9,
        'approved': 4,
        'rejected': 2,
        'mine': {'total': 9},
      });
      expect(stats.totalNotes, 17);
      expect(stats.pendingNotes, 9);
      expect(stats.approvedNotes, 4);
      expect(stats.rejectedNotes, 2);
      expect(stats.draftNotes, 2);
      expect(stats.raisedByMe, 9); // mine.total
    });
  });
}
