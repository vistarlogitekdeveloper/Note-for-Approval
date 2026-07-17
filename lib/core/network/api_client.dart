import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exception.dart';

/// Override for local work:
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1/note-for-approval
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://vistar-crm.onrender.com/api/v1/note-for-approval',
);

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';

const _storage = FlutterSecureStorage();

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// One decoded API response. The server wraps every JSON reply as
/// `{success, data, meta?}`; [data] is the unwrapped payload and [meta] carries
/// pagination, or the post-commit email/PDF outcome on approve.
class ApiResult {
  const ApiResult(this.data, this.meta);
  final dynamic data;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> get asMap => (data as Map).cast<String, dynamic>();
  List<Map<String, dynamic>> get asList =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
}

class ApiClient {
  ApiClient() {
    final options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    );

    _dio = Dio(options);
    // Deliberately interceptor-free: refreshing through _dio would recurse
    // through the 401 handler below.
    _refreshDio = Dio(options);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _kAccessToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final retried = error.requestOptions.extra[_retryFlag] == true;
        if (error.response?.statusCode != 401 ||
            retried ||
            _isAuthRoute(error.requestOptions.path)) {
          return handler.next(error);
        }

        final refreshed = await _refreshOnce();
        if (!refreshed) {
          onSessionExpired?.call();
          return handler.next(error);
        }

        // A consumed multipart stream cannot be replayed, so uploads surface
        // the 401 instead of silently sending an empty body. The refresh above
        // still ran, so the caller's retry will succeed.
        if (error.requestOptions.data is FormData) {
          return handler.next(error);
        }

        try {
          return handler.resolve(await _retry(error.requestOptions));
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    ));
  }

  late final Dio _dio;
  late final Dio _refreshDio;

  static const _retryFlag = '__nfa_retried';

  /// Fired when refresh fails and the session cannot be recovered.
  void Function()? onSessionExpired;

  Dio get dio => _dio;

  bool _isAuthRoute(String path) =>
      path.contains('/auth/login') || path.contains('/auth/refresh');

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await _storage.read(key: _kAccessToken);
    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_retryFlag] = true;
    return _dio.fetch(options);
  }

  // ── Token refresh ─────────────────────────────────────────────────────────
  //
  // The server revokes the presented refresh token and issues a new one on
  // every call. Two concurrent refreshes would each rotate, and whichever
  // landed second would revoke the winner's token — logging the user out. So
  // refreshes are single-flighted: parallel 401s await one in-flight attempt.

  Completer<bool>? _refreshInFlight;

  Future<bool> _refreshOnce() {
    final existing = _refreshInFlight;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshInFlight = completer;

    _performRefresh().then((ok) {
      _refreshInFlight = null;
      completer.complete(ok);
    }).catchError((_) {
      _refreshInFlight = null;
      completer.complete(false);
    });

    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return false;
    try {
      final res = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = (res.data['data'] as Map).cast<String, dynamic>();
      // Both tokens must be stored: the old refresh token is already revoked.
      await saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  // ── Token storage ─────────────────────────────────────────────────────────

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _kAccessToken, value: access);
    await _storage.write(key: _kRefreshToken, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<bool> get hasSession async => await readAccessToken() != null;

  // ── Verbs ─────────────────────────────────────────────────────────────────

  Future<ApiResult> get(String path, {Map<String, dynamic>? params}) =>
      _send(() => _dio.get(path, queryParameters: _clean(params)));

  Future<ApiResult> post(String path, {dynamic data}) =>
      _send(() => _dio.post(path, data: data));

  Future<ApiResult> patch(String path, {dynamic data}) =>
      _send(() => _dio.patch(path, data: data));

  Future<ApiResult> put(String path, {dynamic data}) =>
      _send(() => _dio.put(path, data: data));

  Future<ApiResult> delete(String path) => _send(() => _dio.delete(path));

  Future<ApiResult> upload(String path, FormData data) =>
      _send(() => _dio.post(path, data: data));

  /// For the PDF and attachment downloads, which stream raw bytes rather than
  /// the JSON envelope. Both require the Bearer token, so a bare browser link
  /// to these paths will not work.
  Future<Uint8List> getBytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ApiResult> _send(Future<Response> Function() request) async {
    try {
      return _unwrap(await request());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  ApiResult _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body.containsKey('success')) {
      if (body['success'] == false) {
        throw ApiException.fromDio(DioException(
          requestOptions: res.requestOptions,
          response: res,
        ));
      }
      return ApiResult(body['data'], (body['meta'] as Map?)?.cast<String, dynamic>());
    }
    // Nothing else on this API is un-enveloped; pass it through rather than
    // guess.
    return ApiResult(body, null);
  }

  /// Joi runs with `stripUnknown`, but nulls would still fail type checks —
  /// drop them client-side so optional filters can be passed inline.
  Map<String, dynamic>? _clean(Map<String, dynamic>? params) {
    if (params == null) return null;
    final cleaned = <String, dynamic>{};
    params.forEach((k, v) {
      if (v != null) cleaned[k] = v;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}
