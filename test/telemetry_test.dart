import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/core/telemetry/telemetry.dart';

void main() {
  const uuid = '7f3c2a10-1b2c-4d5e-8f90-a1b2c3d4e5f6';
  const uuid2 = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

  test('screen names carry no record ids', () {
    expect(Telemetry.routePattern('/dashboard'), '/dashboard');
    expect(Telemetry.routePattern('/notes?status=pending&q=diesel'), '/notes');
    expect(Telemetry.routePattern('/notes/new'), '/notes/new');
    expect(Telemetry.routePattern('/notes/$uuid'), '/notes/:id');
    expect(Telemetry.routePattern('/notes/$uuid/edit'), '/notes/:id/edit');
    expect(Telemetry.routePattern('/approvals/mine'), '/approvals/mine');
    expect(Telemetry.routePattern('/admin/users'), '/admin/users');
    expect(
        Telemetry.routePattern(
            'https://api.example.com/api/v1/note-for-approval/notes/$uuid/attachments/$uuid2'),
        '/api/v1/note-for-approval/notes/:id/attachments/:id');
  });

  test('note numbers and other references become :ref', () {
    expect(Telemetry.routePattern('/notes/NFA-2026-0042'), '/notes/:ref');
    expect(Telemetry.routePattern('/notes/nfa-2026-0042/edit'),
        '/notes/:ref/edit');
    expect(Telemetry.routePattern('/notes/NFA%2F2026%2F42'), '/notes/:ref');
    expect(Telemetry.routePattern('/notes/42'), '/notes/:id');
  });

  test('the note journey is named from successful writes', () {
    expect(Telemetry.actionFor('POST', '/notes'), 'note_created');
    expect(Telemetry.actionFor('PATCH', '/notes/$uuid'), 'note_updated');
    expect(
        Telemetry.actionFor('POST', '/notes/$uuid/submit'), 'note_submitted');
    expect(
        Telemetry.actionFor('POST', '/notes/$uuid/approve'), 'note_approved');
    expect(Telemetry.actionFor('POST', '/notes/$uuid/reject'), 'note_rejected');
    expect(
        Telemetry.actionFor('post', '/notes/$uuid/reassign'), 'note_returned');
    expect(Telemetry.actionFor('POST', '/notes/$uuid/attachments'),
        'note_attachment_uploaded');
    expect(Telemetry.actionFor('DELETE', '/notes/$uuid/attachments/$uuid2'),
        'note_attachment_removed');
    expect(Telemetry.actionFor('POST', '/masters/purposes'), 'purpose_created');
    expect(Telemetry.actionFor('PATCH', '/masters/purposes/$uuid'),
        'purpose_updated');
    expect(Telemetry.actionFor('DELETE', '/masters/purposes/$uuid'),
        'purpose_deleted');
    expect(Telemetry.actionFor('POST', '/admin/users'), 'user_created');
    expect(Telemetry.actionFor('PATCH', '/admin/users/$uuid'), 'user_updated');
    expect(Telemetry.actionFor('POST', '/auth/change-password'),
        'password_changed');
  });

  test('reads, downloads, sign-in and unknown paths are not reported', () {
    expect(Telemetry.actionFor('GET', '/notes'), isNull);
    expect(Telemetry.actionFor('GET', '/notes/$uuid'), isNull);
    expect(Telemetry.actionFor('GET', '/notes/$uuid/pdf'), isNull);
    expect(
        Telemetry.actionFor('GET', '/notes/$uuid/attachments/$uuid2'), isNull);
    expect(Telemetry.actionFor('GET', '/approvals/pending'), isNull);
    expect(Telemetry.actionFor('DELETE', '/notes/$uuid'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/login'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/logout'), isNull);
    expect(Telemetry.actionFor('POST', '/auth/refresh'), isNull);
    expect(Telemetry.actionFor('POST', '/something-new'), isNull);
  });

  test(
      'off without ET_APP_ID and ET_WRITE_KEY (the default build); calls are safe',
      () async {
    expect(Telemetry.enabled, isFalse);
    await Telemetry.init();
    Telemetry.screen('/dashboard');
    Telemetry.track('note_created');
    Telemetry.error('api_error', {'endpoint': '/notes', 'method': 'POST'});
    Telemetry.signedIn(userId: 'u1', role: 'admin');
    Telemetry.signedOut();
  });

  test('the interceptor changes nothing about a request or its outcome',
      () async {
    final dio = Dio(
        BaseOptions(baseUrl: 'https://api.invalid/api/v1/note-for-approval'))
      ..httpClientAdapter = _Answer()
      ..interceptors.add(TelemetryInterceptor());
    final ok = await dio.post<dynamic>('/notes', data: {'x': 1});
    expect(ok.statusCode, 201);
    expect((ok.data as Map)['success'], isTrue);
    await expectLater(
      dio.post<dynamic>('/notes/$uuid/approve'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'status', 503)),
    );
  });
}

/// Answers 201 for a new note and 503 for anything else, with no network.
class _Answer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final created = options.path == '/notes';
    return ResponseBody.fromString(
      jsonEncode({'success': created}),
      created ? 201 : 503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
