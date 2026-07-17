import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../features/notes/models/note.dart';

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
