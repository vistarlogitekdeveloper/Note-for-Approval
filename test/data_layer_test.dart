import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/core/network/api_exception.dart';
import 'package:note_approval/features/notes/models/note.dart';
import 'package:note_approval/shared/models/user.dart';

/// These fixtures are the API's real wire shapes: snake_case columns, nested
/// association aliases, and a camelCase `approvalTrail` key. Anything that
/// drifts back to the old spec-shaped assumptions fails here.

const _userJson = {
  'id': '11111111-1111-4111-8111-111111111111',
  'name': 'Asha Rao',
  'email': 'approver1@vistar.com',
  'role': 'approver',
  'hierarchy_level': 1,
  'hierarchy_role_name': 'L1 - Section Head',
  'is_active': true,
  'created_at': '2026-07-17T09:00:00.000Z',
};

const _noteListItemJson = {
  'id': '22222222-2222-4222-8222-222222222222',
  'note_number': 'NFA-2026-0001',
  'purpose_id': '33333333-3333-4333-8333-333333333333',
  'objective_in_detail': 'Replace the ageing forklift',
  'brief_note': 'Unit has failed twice this quarter.',
  'benefit': 'Avoids line stoppage.',
  'cost_impact': 'INR 12,00,000',
  'status': 'pendingApproval',
  'current_level': 2,
  'total_levels': 3,
  'initiator_id': '44444444-4444-4444-8444-444444444444',
  'pdf_url': null,
  'created_at': '2026-07-17T09:05:00.000Z',
  'updated_at': '2026-07-17T10:05:00.000Z',
  'initiator': {
    'id': '44444444-4444-4444-8444-444444444444',
    'name': 'Ravi Kumar',
    'email': 'initiator@vistar.com',
    'role': 'initiator',
    'hierarchy_role_name': null,
  },
  'purpose': {
    'id': '33333333-3333-4333-8333-333333333333',
    'name': 'Capital Expenditure',
  },
};

void main() {
  group('User', () {
    test('reads snake_case hierarchy fields', () {
      final user = User.fromJson(_userJson);
      expect(user.name, 'Asha Rao');
      expect(user.role, UserRole.approver);
      // Regression: these came back null while parsing camelCase, which
      // silently stripped every approver of their level.
      expect(user.hierarchyLevel, 1);
      expect(user.hierarchyRoleName, 'L1 - Section Head');
      expect(user.isActive, isTrue);
      expect(user.createdAt, isNotNull);
    });

    test('superAdmin role value round-trips', () {
      final user = User.fromJson({..._userJson, 'role': 'superAdmin'});
      expect(user.role, UserRole.superAdmin);
      expect(user.role.canAdmin, isTrue);
      expect(user.toJson()['role'], 'superAdmin');
    });

    test('unknown role degrades to initiator rather than throwing', () {
      expect(User.fromJson({..._userJson, 'role': 'wizard'}).role,
          UserRole.initiator);
    });
  });

  group('Note', () {
    test('flattens nested initiator and purpose', () {
      final note = Note.fromJson(_noteListItemJson);
      expect(note.noteNumber, 'NFA-2026-0001');
      // Regression: the server nests these; the old model expected flat
      // `initiatorName` / `purposeLabel` keys and threw on the null.
      expect(note.initiatorName, 'Ravi Kumar');
      expect(note.initiatorEmail, 'initiator@vistar.com');
      expect(note.purposeLabel, 'Capital Expenditure');
      expect(note.objectiveInDetail, 'Replace the ageing forklift');
      expect(note.costImpact, 'INR 12,00,000');
      expect(note.status, NoteStatus.pendingApproval);
      expect(note.currentLevel, 2);
      expect(note.totalLevels, 3);
    });

    test('list responses carry no attachments or trail', () {
      final note = Note.fromJson(_noteListItemJson);
      expect(note.attachments, isEmpty);
      expect(note.approvalTrail, isEmpty);
    });

    test('detail response parses attachments and the camelCase trail key', () {
      final note = Note.fromJson({
        ..._noteListItemJson,
        'attachments': [
          {
            'id': '55555555-5555-4555-8555-555555555555',
            'note_id': _noteListItemJson['id'],
            'file_name': 'quote.pdf',
            'file_path': 'note-for-approval/quote.pdf',
            'mime_type': 'application/pdf',
            'size_bytes': 20481,
            'created_at': '2026-07-17T09:06:00.000Z',
          }
        ],
        'approvalTrail': [
          {
            'id': '66666666-6666-4666-8666-666666666666',
            'note_id': _noteListItemJson['id'],
            'level': 1,
            'role_name': 'L1 - Section Head',
            'approver_id': _userJson['id'],
            'action': 'approved',
            'remark': 'Justified by downtime.',
            'acted_at': '2026-07-17T10:00:00.000Z',
            'approver': {
              'id': _userJson['id'],
              'name': 'Asha Rao',
              'email': 'approver1@vistar.com',
            },
          }
        ],
      });

      expect(note.attachments.single.fileName, 'quote.pdf');
      expect(note.attachments.single.sizeBytes, 20481);

      final action = note.approvalTrail.single;
      expect(action.roleName, 'L1 - Section Head');
      // Regression: approverName lives one level down, under `approver`.
      expect(action.approverName, 'Asha Rao');
      expect(action.remark, 'Justified by downtime.');
      expect(action.actedAt, isNotNull);
      expect(action.isApproved, isTrue);
    });

    test('status enum values match what ?status= expects', () {
      expect(NoteStatus.pendingApproval.wireValue, 'pendingApproval');
      expect(NoteStatus.fromString('pendingApproval'),
          NoteStatus.pendingApproval);
    });
  });

  group('DashboardStats', () {
    test('maps the server key names onto the UI field names', () {
      // Regression: every one of these keys differed from the old model, and
      // the `?? 0` fallbacks turned that into a dashboard of zeros rather than
      // an error.
      final stats = DashboardStats.fromJson(const {
        'total': 12,
        'draft': 2,
        'pendingApproval': 5,
        'approved': 4,
        'rejected': 1,
        'myPendingApprovals': 3,
        'raisedByMe': 6,
        'scope': 'all',
      });

      expect(stats.totalNotes, 12);
      expect(stats.draftNotes, 2);
      expect(stats.pendingNotes, 5);
      expect(stats.approvedNotes, 4);
      expect(stats.rejectedNotes, 1);
      expect(stats.pendingMyAction, 3);
      expect(stats.raisedByMe, 6);
      expect(stats.isGlobalScope, isTrue);
    });
  });

  group('NotePage', () {
    test('reads pagination out of meta', () {
      final page = NotePage.fromResult(
        [Note.fromJson(_noteListItemJson)],
        const {'page': 1, 'limit': 20, 'total': 37, 'pages': 2},
      );
      expect(page.total, 37);
      expect(page.hasMore, isTrue);
    });
  });

  group('ApiException', () {
    DioException dioError(int status, dynamic body) => DioException(
          requestOptions: RequestOptions(path: '/notes'),
          response: Response(
            requestOptions: RequestOptions(path: '/notes'),
            statusCode: status,
            data: body,
          ),
        );

    test('module envelope: error is a string, code a sibling', () {
      final e = ApiException.fromDio(dioError(403, {
        'success': false,
        'error': 'This note is at level 2. You are not the approver for that level.',
        'code': 'NOT_YOUR_LEVEL',
      }));
      expect(e.code, 'NOT_YOUR_LEVEL');
      expect(e.isForbidden, isTrue);
      expect(e.message, contains('level 2'));
    });

    test('validation errors surface the field-level message', () {
      final e = ApiException.fromDio(dioError(400, {
        'success': false,
        'error': '"remark" is not allowed to be empty',
        'code': 'VALIDATION_ERROR',
        'details': [
          {'path': 'remark', 'message': '"remark" is not allowed to be empty'}
        ],
      }));
      expect(e.isValidation, isTrue);
      expect(e.details.single.path, 'remark');
      expect(e.displayMessage, contains('remark'));
    });

    test('body-parser layer nests code and message inside error', () {
      final e = ApiException.fromDio(dioError(400, {
        'success': false,
        'error': {'code': 'VAL_001', 'message': 'Malformed request body: invalid JSON'},
      }));
      expect(e.code, 'VAL_001');
      expect(e.message, 'Malformed request body: invalid JSON');
    });

    test('global 404 has message only — no error, no code', () {
      // This is the exact body the app used to get for every single request,
      // back when the base URL omitted the module mount.
      final e = ApiException.fromDio(dioError(404, {
        'success': false,
        'message': 'Route not found: GET /api/v1/notes',
      }));
      expect(e.message, 'Route not found: GET /api/v1/notes');
      expect(e.code, isNull);
    });

    test('decodes a JSON error delivered as bytes (PDF/attachment downloads)', () {
      final e = ApiException.fromDio(dioError(
        404,
        utf8.encode(jsonEncode(
            {'success': false, 'error': 'File is missing.', 'code': 'FILE_MISSING'})),
      ));
      expect(e.code, 'FILE_MISSING');
      expect(e.message, 'File is missing.');
    });

    test('rate limiter replies in plain text, not JSON', () {
      final e = ApiException.fromDio(dioError(429, 'Too many requests, please try again later.'));
      expect(e.code, 'RATE_LIMITED');
      expect(e.statusCode, 429);
    });

    test('connection failure reports as a network error', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/notes'),
        type: DioExceptionType.connectionError,
      ));
      expect(e.isNetwork, isTrue);
      expect(e.statusCode, isNull);
    });
  });
}
