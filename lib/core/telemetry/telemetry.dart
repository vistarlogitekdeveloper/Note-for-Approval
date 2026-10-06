import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:vistar_event_tracker/vistar_event_tracker.dart'
    show EventType, TrackerConfig, VistarEventTracker, VistarEvents;

import '../network/api_client.dart' show apiBaseUrl;

/// Usage analytics for the Note for Approval portal, sent to the in-house
/// event tracker and read in the Platform Console under Analytics > Event
/// tracker.
///
/// Off unless the build is given both:
///   --dart-define=ET_APP_ID=nfa_app --dart-define=ET_WRITE_KEY=wk_...
/// (register the app in the Platform Console, Settings > Event tracker; the
/// write key only lets a client append events, so it may ship in the app).
/// Optional --dart-define=ET_BASE_URL=... sends a test build's events
/// somewhere other than the API host the app uses (by default, the host of
/// API_BASE_URL, so a UAT build reports to UAT).
///
/// What is sent:
///   * screen views, by route pattern (ids and references replaced:
///     `/notes/:id/edit`)
///   * sign-in / sign-out; the user as `nfa:<user id>`, with their role as the
///     only trait (the sign-in response carries no organisation code)
///   * named actions from successful API writes (see [_actions]):
///     `note_created`, `note_submitted`, `note_approved`, `note_rejected`, ...
///   * failed API calls (5xx or no connection), and client errors by TYPE
///     only (never the message, which can quote a server reply)
/// Never sent: request or response bodies, note titles, bodies or numbers,
/// amounts, remarks, attachment names, approver or user names, emails, or any
/// other record content. A write is counted as the bare event name, with no
/// properties.
///
/// NEVER IN THE WAY OF WORK. Nothing here is awaited by a screen, a note, an
/// approval, a sign-in or a sign-out; start-up waits at most [_initBudget];
/// every call swallows its own failures; the queue is capped at [_maxQueue]
/// events (oldest dropped) and lives in shared preferences; sending is in the
/// background with the SDK's backoff.
abstract final class Telemetry {
  static const _appId = String.fromEnvironment('ET_APP_ID');
  static const _writeKey = String.fromEnvironment('ET_WRITE_KEY');
  static const _baseUrlOverride = String.fromEnvironment('ET_BASE_URL');
  static const _appVersion = String.fromEnvironment('APP_VERSION');
  static const _initBudget = Duration(seconds: 2);
  static const _maxQueue = 200;

  static bool get enabled => _appId != '' && _writeKey != '';

  static VistarEventTracker get _t => VistarEventTracker.instance;
  static bool get _on => enabled && _t.isInitialized;

  static String? _lastScreen;
  static Future<void>? _resetting;

  static String get _origin {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    final u = Uri.parse(apiBaseUrl);
    return '${u.scheme}://${u.authority}';
  }

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await _t
          .init(TrackerConfig(
            appId: _appId,
            writeKey: _writeKey,
            baseUrl: _origin,
            appVersion: _appVersion.isEmpty ? null : _appVersion,
            maxQueueSize: _maxQueue,
            // The SDK's own error capture sends the exception message and
            // stack, and a message here can quote a server reply (a note
            // title, an amount, a name). [_captureErrors] sends the type only.
            autoCaptureErrors: false,
          ))
          .timeout(_initBudget);
      _captureErrors();
    } catch (_) {
      // Analytics must never stop the app from starting.
    }
  }

  /// Client errors, by type only. Chains to whatever handled them before, so
  /// the app's own error handling is unchanged.
  static void _captureErrors() {
    if (!_on) return;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      _clientError(details.exception, fatal: false, library: details.library);
      previous?.call(details);
    };
    final dispatcher = PlatformDispatcher.instance;
    final previousAsync = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      _clientError(error, fatal: true);
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  static void _clientError(Object e, {required bool fatal, String? library}) {
    try {
      error(VistarEvents.clientError, {
        'error': e.runtimeType.toString(),
        if (library != null) 'library': library,
        'fatal': fatal,
      });
    } catch (_) {}
  }

  /// A screen, by its route pattern. Repeats are dropped, and so is the
  /// session-restore splash (a loader, not a screen anyone uses).
  static void screen(String location) {
    if (!_on) return;
    final name = routePattern(location);
    if (name == _lastScreen || name == '/splash') return;
    _lastScreen = name;
    _guard(() => _t.screen(name));
  }

  static void track(String name, [Map<String, dynamic>? properties]) {
    if (_on) _guard(() => _t.track(name, properties: properties));
  }

  static void error(String name, Map<String, dynamic> properties) {
    if (_on) {
      _guard(
          () => _t.track(name, properties: properties, type: EventType.error));
    }
  }

  static void _guard(void Function() fn) {
    try {
      fn();
    } catch (_) {
      // Analytics never surfaces as an app error.
    }
  }

  /// Fire and forget: the sign-in never waits for analytics.
  ///
  /// Called just BEFORE the auth state changes. With no sign-out in flight the
  /// SDK sets the user synchronously (before its first await), so the screen
  /// the sign-in leads to is already attributed to them.
  static void signedIn({required String userId, String? role}) {
    if (!_on || userId.isEmpty) return;
    final id = 'nfa:$userId';
    final traits = <String, dynamic>{
      if (role != null && role.isNotEmpty) 'role': role,
    };
    final pending = _resetting;
    if (pending == null) {
      _identify(id, traits);
      return;
    }
    // A sign-out just before (a shared desk changing hands) resets the
    // identity; let it finish so this one is not wiped by it.
    unawaited(() async {
      try {
        await pending.timeout(const Duration(seconds: 5), onTimeout: () {});
      } catch (_) {}
      _identify(id, traits);
    }());
  }

  static void _identify(String id, Map<String, dynamic> traits) {
    try {
      unawaited(_t.identify(id, traits: traits).catchError((Object _) {}));
    } catch (_) {}
  }

  /// Fire and forget: the sign-out never waits for analytics (the SDK's reset
  /// sends what is queued first, which can take a while on a poor network).
  static void signedOut() {
    _lastScreen = null;
    if (!_on) return;
    try {
      late final Future<void> done;
      done = _t.reset().catchError((Object _) {}).whenComplete(() {
        if (identical(_resetting, done)) _resetting = null;
      });
      _resetting = done;
    } catch (_) {}
  }

  /// `/notes/9f3c...-.../edit?x=1` -> `/notes/:id/edit`.
  ///
  /// Any segment with a digit in it is replaced: numbers and uuids become
  /// `:id`; everything else with a digit (note numbers such as NFA-2026-0042)
  /// becomes `:ref`. The query string is dropped. An API version segment
  /// (`v1`) is kept.
  static String routePattern(String location) {
    final path = Uri.tryParse(location)?.path ?? location.split('?').first;
    return path.split('/').map((s) {
      if (s.isEmpty) return s;
      if (RegExp(r'^\d+$').hasMatch(s)) return ':id';
      if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-', caseSensitive: false)
          .hasMatch(s)) {
        return ':id';
      }
      if (RegExp(r'^v\d{1,2}$').hasMatch(s)) return s;
      if (RegExp(r'\d').hasMatch(s)) return ':ref';
      return s;
    }).join('/');
  }

  /// Successful API writes worth naming, by method and path (ids stripped).
  /// First match wins; anything else (reads, PDF and attachment downloads,
  /// sign-in, unknown paths) is not reported.
  static final List<(String, RegExp, String)> _actions = [
    // The note journey.
    ('POST', RegExp(r'^/notes$'), 'note_created'),
    ('PATCH', RegExp(r'^/notes/:(id|ref)$'), 'note_updated'),
    ('POST', RegExp(r'^/notes/:(id|ref)/submit$'), 'note_submitted'),
    ('POST', RegExp(r'^/notes/:(id|ref)/approve$'), 'note_approved'),
    ('POST', RegExp(r'^/notes/:(id|ref)/reject$'), 'note_rejected'),
    ('POST', RegExp(r'^/notes/:(id|ref)/reassign$'), 'note_returned'),
    (
      'POST',
      RegExp(r'^/notes/:(id|ref)/attachments$'),
      'note_attachment_uploaded'
    ),
    (
      'DELETE',
      RegExp(r'^/notes/:(id|ref)/attachments/:(id|ref)$'),
      'note_attachment_removed'
    ),
    // Admin: purposes and users.
    ('POST', RegExp(r'^/masters/purposes$'), 'purpose_created'),
    ('PATCH', RegExp(r'^/masters/purposes/:(id|ref)$'), 'purpose_updated'),
    ('DELETE', RegExp(r'^/masters/purposes/:(id|ref)$'), 'purpose_deleted'),
    ('POST', RegExp(r'^/admin/users$'), 'user_created'),
    ('PATCH', RegExp(r'^/admin/users/:(id|ref)$'), 'user_updated'),
    // Account.
    ('POST', RegExp(r'^/auth/change-password$'), 'password_changed'),
  ];

  /// The business event for a successful API call, or null.
  static String? actionFor(String method, String path) {
    final pattern = routePattern(path);
    for (final (m, re, name) in _actions) {
      if (m == method.toUpperCase() && re.hasMatch(pattern)) return name;
    }
    return null;
  }
}

/// Reports named actions and failed calls from the app's one API client
/// (ApiClient.dio). Adds no headers and changes nothing about the request or
/// its handling.
class TelemetryInterceptor extends Interceptor {
  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    // This client uses Dio's default validateStatus, so only a 2xx arrives
    // here; a 2xx whose envelope says `success: false` did not happen either.
    final code = response.statusCode ?? 0;
    if (Telemetry.enabled && code >= 200 && code < 300) {
      String? name;
      try {
        final body = response.data;
        final refused = body is Map && body['success'] == false;
        final o = response.requestOptions;
        if (!refused) name = Telemetry.actionFor(o.method, o.path);
      } catch (_) {}
      if (name != null) Telemetry.track(name);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (Telemetry.enabled) {
      try {
        final status = err.response?.statusCode;
        // A 4xx is a decision the server made, and a cancel is the app's own.
        if ((status == null || status >= 500) &&
            err.type != DioExceptionType.cancel) {
          Telemetry.error('api_error', {
            'endpoint': Telemetry.routePattern(err.requestOptions.path),
            'method': err.requestOptions.method,
            if (status != null) 'status': status,
            'kind': err.type.name,
          });
        }
      } catch (_) {}
    }
    handler.next(err);
  }
}
