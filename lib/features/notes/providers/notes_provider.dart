import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';

// ── My Notes ─────────────────────────────────────────────────────────────────
final myNotesProvider = FutureProvider<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getMyNotes();
});

// ── Pending approvals (for approvers) ────────────────────────────────────────
final pendingApprovalsProvider = FutureProvider<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getPendingApprovals();
});

// ── Single note detail ────────────────────────────────────────────────────────
final noteDetailProvider = FutureProvider.family<Note, String>((ref, id) async {
  return ref.read(notesRepositoryProvider).getNoteById(id);
});

// ── Dashboard stats ───────────────────────────────────────────────────────────
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  return ref.read(notesRepositoryProvider).getDashboardStats();
});

// ── Recent notes (for dashboard) ─────────────────────────────────────────────
final recentNotesProvider = FutureProvider<List<Note>>((ref) async {
  return ref.read(notesRepositoryProvider).getRecentNotes();
});

// ── Purpose/Objective master list ─────────────────────────────────────────────
final purposesProvider = FutureProvider<List<PurposeMaster>>((ref) async {
  return ref.read(notesRepositoryProvider).getPurposes();
});

// ── Notes filter (for My Notes list) ─────────────────────────────────────────
final notesFilterProvider = StateProvider<String?>((ref) => null);

final filteredNotesProvider = FutureProvider<List<Note>>((ref) async {
  final filter = ref.watch(notesFilterProvider);
  return ref.read(notesRepositoryProvider).getMyNotes(status: filter);
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

  Future<Note?> saveDraft(Map<String, dynamic> data, {String? editId}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final note = editId != null
          ? await _repo.updateNote(editId, {...data, 'status': 'draft'})
          : await _repo.createNote({...data, 'status': 'draft'});
      state = state.copyWith(loading: false, success: 'Draft saved');
      return note;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return null;
    }
  }

  Future<Note?> submit(Map<String, dynamic> data, {String? editId}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      Note note;
      if (editId != null) {
        note = await _repo.updateNote(editId, data);
        note = await _repo.submitNote(editId);
      } else {
        note = await _repo.createNote(data);
        note = await _repo.submitNote(note.id);
      }
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
}
