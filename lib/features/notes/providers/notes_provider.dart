import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/models/user.dart';

// Every list below is `autoDispose`, and that is load-bearing rather than
// tidiness. A plain FutureProvider caches for the life of the app: a queue
// read once while it was empty stays empty for the whole session, no matter
// what happens on the server afterwards. That is exactly how an approver came
// to see "You're all caught up" while a note sat waiting for them.
//
// autoDispose drops the cache when the last watcher goes away, so leaving a
// screen and coming back re-reads it. Anything that mutates data should still
// invalidate explicitly — that covers the case where the screen never
// unmounted.

// ── My Notes ─────────────────────────────────────────────────────────────────
final myNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getMyNotes();
});

// ── My own decision history ──────────────────────────────────────────────────
final myDecisionsFilterProvider = StateProvider<String?>((ref) => null);

final myDecisionsProvider =
    FutureProvider.autoDispose<MyDecisionPage>((ref) async {
  final action = ref.watch(myDecisionsFilterProvider);
  return ref.read(notesRepositoryProvider).getMyDecisions(action: action);
});

// ── Pending approvals (for approvers) ────────────────────────────────────────
final pendingApprovalsProvider =
    FutureProvider.autoDispose<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getPendingApprovals();
});

// ── Single note detail ────────────────────────────────────────────────────────
final noteDetailProvider =
    FutureProvider.family.autoDispose<Note, String>((ref, id) async {
  return ref.read(notesRepositoryProvider).getNoteById(id);
});

// ── Dashboard stats ───────────────────────────────────────────────────────────
final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) async {
  return ref.read(notesRepositoryProvider).getDashboardStats();
});

// Which KPI breakdown the dashboard shows, for admins. false = all visible (the
// system-overview default), true = only notes I raised. The stats response
// already carries both scopes, so flipping this just re-reads the cached object
// — no network round-trip.
final dashboardScopeMineProvider = StateProvider<bool>((ref) => false);

// ── Recent notes (for dashboard) ─────────────────────────────────────────────
final recentNotesProvider =
    FutureProvider.autoDispose<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getRecentNotes();
});

// ── Purpose/Objective master list ─────────────────────────────────────────────
final purposesProvider =
    FutureProvider.autoDispose<List<PurposeMaster>>((ref) async {
  return ref.read(notesRepositoryProvider).getPurposes();
});

// ── People who can be put on a note's approval chain ─────────────────────────
final selectableApproversProvider =
    FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.read(notesRepositoryProvider).getSelectableApprovers();
});

// ── Notes filter (for My Notes list) ─────────────────────────────────────────
final notesFilterProvider = StateProvider<String?>((ref) => null);

// Scope of the My Notes list. true = only notes I raised (the default, and the
// only scope a non-admin ever has); false = every note I'm allowed to see,
// which for an admin is all notes in the system. The server enforces this — an
// admin's `mine:false` resolves to an empty visibility filter (everything),
// a non-admin's to just the notes they're a party to.
final notesScopeMineProvider = StateProvider<bool>((ref) => true);

final filteredNotesProvider =
    FutureProvider.autoDispose<List<Note>>((ref) async {
  final filter = ref.watch(notesFilterProvider);
  // The `!isAdmin` guard lives HERE so it can't diverge from the screen: a
  // non-admin is always mine-only regardless of what the scope flag says (it
  // could have been flipped to false by a dashboard KPI tap, which is
  // admin-oriented). Without this, a non-admin could fetch all-visible notes
  // under a "My Notes" header with no toggle to escape.
  final isAdmin = ref.watch(authProvider).user?.role.canAdmin ?? false;
  final mineOnly = !isAdmin || ref.watch(notesScopeMineProvider);
  final repo = ref.read(notesRepositoryProvider);
  if (mineOnly) return repo.getMyNotes(status: filter);
  final page = await repo.getNotes(mine: false, status: filter);
  return page.notes;
});

// ── Create/Edit note form state ───────────────────────────────────────────────
class NoteFormState {
  final bool loading;
  final String? error;
  final String? success;

  const NoteFormState({this.loading = false, this.error, this.success});
  NoteFormState copyWith({bool? loading, String? error, String? success}) =>
      NoteFormState(
        loading: loading ?? this.loading,
        error: error,
        success: success,
      );
}

final noteFormProvider =
    StateNotifierProvider.autoDispose<NoteFormNotifier, NoteFormState>(
  (ref) => NoteFormNotifier(ref.read(notesRepositoryProvider)),
);

class NoteFormNotifier extends StateNotifier<NoteFormState> {
  NoteFormNotifier(this._repo) : super(const NoteFormState());
  final NotesRepository _repo;

  /// [attachments] are files staged in the form but not yet on the server. A
  /// note has to exist before anything can be attached to it, so they go up
  /// once the create/update lands.
  Future<Note?> saveDraft(
    Map<String, dynamic> data, {
    String? editId,
    List<AttachmentUpload> attachments = const [],
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final note = editId != null
          ? await _repo.updateNote(editId, data)
          : await _repo.createNote(data);
      if (attachments.isNotEmpty) {
        await _repo.uploadAttachments(note.id, attachments);
      }
      state = state.copyWith(loading: false, success: 'Draft saved');
      return note;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  Future<Note?> submit(
    Map<String, dynamic> data, {
    String? editId,
    List<AttachmentUpload> attachments = const [],
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final draft = editId != null
          ? await _repo.updateNote(editId, data)
          : await _repo.createNote(data);

      // The server refuses attachments on anything but a draft, so they must
      // land before the submit flips the status.
      if (attachments.isNotEmpty) {
        await _repo.uploadAttachments(draft.id, attachments);
      }

      final note = await _repo.submitNote(draft.id);
      state = state.copyWith(loading: false, success: 'Note submitted for approval');
      return note;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> approve(String noteId, String remark) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.approveNote(noteId, remark);
      state = state.copyWith(loading: false, success: 'Note approved');
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> reject(String noteId, String remark) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.rejectNote(noteId, remark);
      state = state.copyWith(loading: false, success: 'Note rejected');
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// Send the note back to its creator to revise the hierarchy and resubmit.
  Future<bool> reassign(String noteId, String remark) async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _repo.reassignNote(noteId, remark);
      state = state.copyWith(loading: false, success: 'Note sent back for revision');
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }
}
