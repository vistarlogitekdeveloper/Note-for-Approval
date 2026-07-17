import 'dart:convert';

import 'package:dio/dio.dart';

/// A normalised error from the Note-for-Approval API.
///
/// The server does not speak one error dialect. Four layers can answer a
/// request, each with its own body shape, so everything funnels through
/// [ApiException.fromDio] and comes out as `message` + optional [code].
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details = const [],
  });

  final String message;

  /// Machine code such as `INVALID_CREDENTIALS`, `NOT_YOUR_LEVEL`,
  /// `VALIDATION_ERROR`. Absent on 500s and on global 404s.
  final String? code;

  final int? statusCode;

  /// Field-level validation failures: `[{path, message}]`.
  final List<ValidationDetail> details;

  bool get isNetwork => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => code == 'VALIDATION_ERROR';

  /// The module is stubbed out server-side because no JWT secret is configured.
  bool get isModuleDisabled => code == 'NFA_DISABLED';

  /// The refresh token was rejected — the session is unrecoverable.
  bool get isRefreshRejected => code == 'INVALID_REFRESH_TOKEN';

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(message: _networkMessage(e.type));
    }

    final body = _decodeBody(res.data);
    final status = res.statusCode;

    if (body is Map) {
      final error = body['error'];

      // Module envelope: `error` is a plain string, `code` a sibling key.
      if (error is String && error.isNotEmpty) {
        return ApiException(
          message: error,
          code: body['code'] as String?,
          statusCode: status,
          details: _parseDetails(body['details']),
        );
      }

      // Body-parser layer (app.js) nests code+message inside `error`.
      if (error is Map) {
        return ApiException(
          message: (error['message'] as String?) ?? _statusMessage(status),
          code: error['code'] as String?,
          statusCode: status,
        );
      }

      // Global notFound/errorHandler: `message` only, no `error`, no `code`.
      final message = body['message'];
      if (message is String && message.isNotEmpty) {
        return ApiException(message: message, statusCode: status);
      }
    }

    // Rate limiter returns plain text, not JSON.
    if (body is String && body.trim().isNotEmpty && status == 429) {
      return ApiException(
        message: body.trim(),
        code: 'RATE_LIMITED',
        statusCode: status,
      );
    }

    return ApiException(message: _statusMessage(status), statusCode: status);
  }

  /// Dio hands back raw bytes when `responseType: bytes` was requested, which
  /// is exactly when a JSON error body is least expected — the PDF and
  /// attachment downloads.
  static dynamic _decodeBody(dynamic data) {
    if (data is List<int>) {
      try {
        return jsonDecode(utf8.decode(data));
      } catch (_) {
        return null;
      }
    }
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  static List<ValidationDetail> _parseDetails(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((d) => ValidationDetail(
              path: d['path']?.toString() ?? '',
              message: d['message']?.toString() ?? '',
            ))
        .toList();
  }

  static String _networkMessage(DioExceptionType type) => switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The server took too long to respond. Check your connection and try again.',
        DioExceptionType.cancel => 'Request cancelled.',
        _ => 'Cannot reach the server. Check your connection and try again.',
      };

  static String _statusMessage(int? status) => switch (status) {
        400 => 'The request was rejected. Please check the form and try again.',
        401 => 'Your session has expired. Please sign in again.',
        403 => 'You do not have permission to do that.',
        404 => 'Not found.',
        409 => 'That conflicts with the current state. Refresh and try again.',
        429 => 'Too many attempts. Please wait and try again.',
        503 => 'The service is unavailable. Please try again shortly.',
        _ => 'Something went wrong on the server. Please try again.',
      };

  /// Prefers the first field-level message, which is more specific than the
  /// joined summary Joi puts in `error`.
  String get displayMessage =>
      details.isNotEmpty ? details.first.message : message;

  @override
  String toString() => displayMessage;
}

class ValidationDetail {
  const ValidationDetail({required this.path, required this.message});
  final String path;
  final String message;
}
