import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../features/notes/models/note.dart';
import '../../../shared/models/user.dart';

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.read(apiClientProvider)),
);

/// A file staged for upload. Web gives [bytes], mobile/desktop gives [path];
/// exactly one is needed.
class AttachmentUpload {
  const AttachmentUpload({required this.fileName, this.bytes, this.path})
      : assert(bytes != null || path != null,
            'AttachmentUpload needs either bytes or a path');

  final String fileName;
  final Uint8List? bytes;
  final String? path;
}

/// One rung of a note's approval chain as the form holds it, before it is sent.
/// Level is positional — the order of the list is the order of approval — so it
/// is assigned at send time rather than stored here, where a stale index would
/// silently reorder the route.
class ApproverChoice {
  const ApproverChoice({required this.userId, this.roleName});
  final String userId;

  /// Defaults server-side to the user's own hierarchy role name.
  final String? roleName;
}

/// The result of an approve/reject. Email and PDF generation run after the
/// transaction commits, so their failure is reported here rather than thrown —
/// the decision itself already stuck.
class DecisionOutcome {
  const DecisionOutcome({
    required this.note,
    required this.emailSent,
    this.emailIssue,
    this.pdfGenerated = false,
    this.pdfError,
  });

  final Note note;
  final bool emailSent;

  /// Why notification did not go out, when it did not.
  final String? emailIssue;

  /// True only on the final approval, which is when the PDF is produced.
  final bool pdfGenerated;
  final String? pdfError;

  factory DecisionOutcome.fromResult(Note note, Map<String, dynamic>? meta) {
    final notified = (meta?['notified'] as Map?)?.cast<String, dynamic>();
    final pdf = (meta?['pdf'] as Map?)?.cast<String, dynamic>();
    return DecisionOutcome(
      note: note,
      emailSent: notified?['sent'] as bool? ?? false,
      emailIssue: (notified?['skipped'] ?? notified?['error'] ?? notified?['reason'])
          as String?,
      pdfGenerated: pdf?['generated'] as bool? ?? false,
      pdfError: pdf?['error'] as String?,
    );
  }
}

class NotesRepository {
  NotesRepository(this._api);
  final ApiClient _api;

  /// The server caps `limit` at 100 and defaults to 20; the screens show
  /// unpaginated lists, so ask for the maximum.
  static const _listLimit = 100;

  // ── Reads ─────────────────────────────────────────────────────────────────

  Future<NotePage> getNotes({
    bool mine = false,
    String? status,
    String? search,
    int page = 1,
    int limit = _listLimit,
  }) async {
    final res = await _api.get(ApiEndpoints.notes, params: {
      'mine': mine,
      'status': status,
      'search': search,
      'page': page,
      'limit': limit,
    });
    return NotePage.fromResult(_notes(res), res.meta);
  }

  Future<List<Note>> getMyNotes({String? status}) async {
    final res = await _api.get(ApiEndpoints.notes, params: {
      'mine': true,
      'status': status,
      'limit': _listLimit,
    });
    return _notes(res);
  }

  Future<List<Note>> getPendingApprovals() async {
    final res = await _api.get(
      ApiEndpoints.pendingApprovals,
      params: {'limit': _listLimit},
    );
    return _notes(res);
  }

  Future<List<Note>> getRecentNotes() async {
    final res = await _api.get(ApiEndpoints.notes, params: {'limit': 5});
    return _notes(res);
  }

  /// The only response carrying `attachments` and `approvalTrail`.
  Future<Note> getNoteById(String id) async {
    final res = await _api.get(ApiEndpoints.noteById(id));
    return Note.fromJson(res.asMap);
  }

  Future<DashboardStats> getDashboardStats() async {
    final res = await _api.get(ApiEndpoints.dashboardStats);
    return DashboardStats.fromJson(res.asMap);
  }

  Future<List<PurposeMaster>> getPurposes({bool includeInactive = false}) async {
    final res = await _api.get(
      ApiEndpoints.purposes,
      params: {'includeInactive': includeInactive},
    );
    return res.asList.map(PurposeMaster.fromJson).toList();
  }

  // ── Purpose masters (admin writes) ────────────────────────────────────────

  Future<PurposeMaster> createPurpose(String name) async {
    final res = await _api.post(ApiEndpoints.purposes, data: {'name': name});
    return PurposeMaster.fromJson(res.asMap);
  }

  Future<PurposeMaster> updatePurpose(String id, {String? name, bool? isActive}) async {
    final res = await _api.patch(ApiEndpoints.purposeById(id), data: {
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
    });
    return PurposeMaster.fromJson(res.asMap);
  }

  /// Soft-deletes when any note references the purpose — an approved note has
  /// to keep resolving its purpose for the PDF. The response says which
  /// happened; `true` means it was only deactivated.
  Future<bool> deletePurpose(String id) async {
    final res = await _api.delete(ApiEndpoints.purposeById(id));
    final data = res.data;
    return data is Map && data['soft_deleted'] == true;
  }

  /// The people who can be put on a note's own approval chain: active users who
  /// are able to approve something. Returns the same shape as the user admin
  /// endpoints but is readable by any signed-in user, since an initiator needs
  /// it to build a chain.
  Future<List<User>> getSelectableApprovers() async {
    final res = await _api.get(ApiEndpoints.approvers);
    return res.asList.map(User.fromJson).toList();
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<Note> createNote(Map<String, dynamic> data) async {
    final res = await _api.post(ApiEndpoints.notes, data: _toWire(data));
    return Note.fromJson(res.asMap);
  }

  Future<Note> updateNote(String id, Map<String, dynamic> data) async {
    final res = await _api.patch(ApiEndpoints.noteById(id), data: _toWire(data));
    return Note.fromJson(res.asMap);
  }

  Future<Note> submitNote(String id) async {
    final res = await _api.post(ApiEndpoints.submitNote(id));
    return Note.fromJson(res.asMap);
  }

  /// [remark] is mandatory server-side and rejected if blank.
  Future<DecisionOutcome> approveNote(String id, String remark) async {
    final res = await _api.post(
      ApiEndpoints.approveNote(id),
      data: {'remark': remark},
    );
    return DecisionOutcome.fromResult(Note.fromJson(res.asMap), res.meta);
  }

  Future<DecisionOutcome> rejectNote(String id, String remark) async {
    final res = await _api.post(
      ApiEndpoints.rejectNote(id),
      data: {'remark': remark},
    );
    return DecisionOutcome.fromResult(Note.fromJson(res.asMap), res.meta);
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  /// Drafts only, initiator only — the server rejects anything else. Max 10
  /// files, 20 MB each.
  Future<List<NoteAttachment>> uploadAttachments(
    String noteId,
    List<AttachmentUpload> files,
  ) async {
    final parts = <MapEntry<String, MultipartFile>>[];
    for (final file in files) {
      final part = file.bytes != null
          ? MultipartFile.fromBytes(
              file.bytes!,
              filename: file.fileName,
              contentType: _mediaTypeFor(file.fileName),
            )
          : await MultipartFile.fromFile(
              file.path!,
              filename: file.fileName,
              contentType: _mediaTypeFor(file.fileName),
            );
      // The server's multer instance listens on the field name `files`.
      parts.add(MapEntry('files', part));
    }

    final res = await _api.upload(
      ApiEndpoints.noteAttachments(noteId),
      FormData()..files.addAll(parts),
    );
    return res.asList.map(NoteAttachment.fromJson).toList();
  }

  Future<Uint8List> downloadAttachment(String noteId, String attachmentId) =>
      _api.getBytes(ApiEndpoints.noteAttachmentFile(noteId, attachmentId));

  Future<void> deleteAttachment(String noteId, String attachmentId) =>
      _api.delete(ApiEndpoints.noteAttachmentFile(noteId, attachmentId));

  /// Fetches the generated PDF. This needs the Bearer token, so it cannot be
  /// opened as a plain link — hand the bytes to `printing`/`Printing.sharePdf`.
  Future<Uint8List> downloadNotePdf(String noteId) =>
      _api.getBytes(ApiEndpoints.notePdf(noteId));

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Note> _notes(ApiResult res) => res.asList.map(Note.fromJson).toList();

  /// Forms are written in Dart casing; the API speaks snake_case and runs Joi
  /// with `stripUnknown`, so an untranslated key is dropped without an error.
  static const _wireKeys = {
    'purposeId': 'purpose_id',
    'purpose_id': 'purpose_id',
    'objectiveInDetail': 'objective_in_detail',
    'objective_in_detail': 'objective_in_detail',
    'briefNote': 'brief_note',
    'brief_note': 'brief_note',
    'benefit': 'benefit',
    'costImpact': 'cost_impact',
    'cost_impact': 'cost_impact',
  };

  Map<String, dynamic> _toWire(Map<String, dynamic> form) {
    final out = <String, dynamic>{};
    form.forEach((key, value) {
      final wireKey = _wireKeys[key];
      // Anything unmapped — `status`, say — is client-side only. Status is
      // driven by the submit/approve endpoints, never by the note body.
      if (wireKey != null && value != null) out[wireKey] = value;
    });

    // The approval chain is a list of objects rather than a scalar, so it does
    // not go through _wireKeys. An empty list is meaningful and must survive:
    // it clears a chain back to the global hierarchy. Absent means "leave as
    // is", which is why null is dropped and [] is not.
    final chain = form['approvers'];
    if (chain is List<ApproverChoice>) {
      out['approvers'] = [
        for (var i = 0; i < chain.length; i++)
          {
            'level': i + 1,
            'user_id': chain[i].userId,
            if (chain[i].roleName != null) 'role_name': chain[i].roleName,
          }
      ];
    }
    return out;
  }

  /// Uploads are gated on extension *and* MIME type, and file_picker does not
  /// supply a MIME, so derive it here or the server answers 400.
  DioMediaType? _mediaTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    return switch (ext) {
      'pdf' => DioMediaType('application', 'pdf'),
      'png' => DioMediaType('image', 'png'),
      'jpg' || 'jpeg' => DioMediaType('image', 'jpeg'),
      'docx' => DioMediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document'),
      'xlsx' => DioMediaType('application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      _ => null,
    };
  }
}
