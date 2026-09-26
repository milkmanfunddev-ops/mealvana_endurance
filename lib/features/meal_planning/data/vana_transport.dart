import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/logging_service.dart';
import '../../ai_credits/domain/insufficient_credits_exception.dart';
import 'vana_exceptions.dart';

/// Builds the `http.Client` a request uses. Injected so tests can hand in a
/// `MockClient`; production uses `http.Client.new`.
typedef HttpClientFactory = http.Client Function();

/// The headers + line stream of a successful NDJSON response.
class NdjsonResponse {
  const NdjsonResponse({required this.headers, required this.lines});

  /// Response headers (lower-cased keys, as `http` delivers them).
  final Map<String, String> headers;

  /// One decoded JSON object per NDJSON line. Blank / non-JSON / non-object
  /// lines are skipped. Completes when the connection closes.
  final Stream<Map<String, dynamic>> lines;

  String? get conversationId => headers['x-conversation-id'];
}

/// Shared HTTP plumbing for the Vana edge functions: bearer auth from the
/// current Supabase session, JSON bodies, the status → exception mapping in
/// `vana_exceptions.dart`, and NDJSON line splitting.
///
/// Used by [VanaChatRepository] (streaming), [VanaActionClient] (unary) and,
/// through [VanaChatRepository], the legacy `AiCoachChatRepository`.
///
/// Nothing waits forever (testing-wave 129, Finding 89-005): a unary call
/// that has not answered within [timeout] ([longTimeout] for the
/// [longActions]), or a stream whose headers have not come within
/// [longTimeout], is dropped and raised as [VanaOfflineException], so the
/// screen says it needs a connection and offers its retry.
///
/// A 401 is the server saying this session is not one it knows (testing-wave
/// 117-011: a global logout elsewhere left the phone signed in, and Vana
/// answered 401 eleven times while the card sat on "Looking at your day…").
/// On a 401 the transport asks GoTrue to refresh the session ONCE. A refused
/// refresh token means the server ended the session: the phone signs out
/// locally and the router lands on Log In. A refresh that failed for a reason
/// that may pass later (offline) leaves the session alone. Either way the
/// call that got the 401 is not retried: it raises
/// [VanaUnauthenticatedException] and the next tap uses whatever session is
/// then current. Concurrent 401s share one refresh.
class VanaTransport {
  VanaTransport({
    required SupabaseClient supabase,
    required AppConfig config,
    required AppLogger logger,
    HttpClientFactory? clientFactory,
    this.timeout = defaultTimeout,
    this.longTimeout = defaultLongTimeout,
  }) : _supabase = supabase,
       _config = config,
       _logger = logger,
       _clientFactory = clientFactory ?? http.Client.new;

  final SupabaseClient _supabase;
  final AppConfig _config;
  final AppLogger _logger;
  final HttpClientFactory _clientFactory;

  /// How long a unary call may take before it counts as offline.
  final Duration timeout;

  /// The budget for the [longActions] and for a chat turn's headers: work
  /// that runs a model or builds a list server-side.
  final Duration longTimeout;

  static const defaultTimeout = Duration(seconds: 20);
  static const defaultLongTimeout = Duration(seconds: 90);

  /// `vana-action` types that run a model or rebuild a plan or list, read
  /// from the body's `type`.
  static const longActions = {
    'confirm_plan',
    'pantry_photo',
    'draft_week',
    'plan_week',
    'next_picker',
    'same_as_last_time',
    'swap_ingredient',
    'rebuild_shopping_list',
    'use_plan_again',
    'new_plan',
    'rewind',
  };

  Duration _timeoutFor(Map<String, dynamic> body) =>
      longActions.contains(body['type']) ? longTimeout : timeout;

  static const _context = 'VANA_TRANSPORT';

  SupabaseClient get supabase => _supabase;

  Uri functionUri(String functionName) =>
      Uri.parse('${_config.supabaseUrl}/functions/v1/$functionName');

  /// The signed-in user's auth id, or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  http.Request _buildRequest(String functionName, Map<String, dynamic> body) {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const VanaUnauthenticatedException('No active session');
    }
    return http.Request('POST', functionUri(functionName))
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..headers['apikey'] = _config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
  }

  /// POST [body] to [functionName] and return the streamed NDJSON lines.
  ///
  /// Throws the `vana_exceptions.dart` types (and
  /// [InsufficientCreditsException] on 402, [VanaUnavailableException] when
  /// the gateway refused us) before any line is emitted.
  Future<NdjsonResponse> streamNdjson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final request = _buildRequest(functionName, body);
    _logger.info('POST ${request.url} (stream)', context: _context);

    final client = _clientFactory();
    http.StreamedResponse streamed;
    try {
      streamed = await client.send(request).timeout(longTimeout);
    } catch (e, st) {
      client.close();
      _logger.error(
        'Network error streaming $functionName',
        context: _context,
        error: e,
        stackTrace: st,
      );
      throw VanaOfflineException(e);
    }

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final responseBody = await streamed.stream.bytesToString();
      client.close();
      if (streamed.statusCode == 401) await recoverSessionAfter401();
      throw mapErrorResponse(streamed.statusCode, responseBody);
    }

    return NdjsonResponse(
      headers: streamed.headers,
      lines: _splitLines(streamed.stream, onDone: client.close),
    );
  }

  /// POST [body] to [functionName] and decode the JSON object response.
  Future<Map<String, dynamic>> postJson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final request = _buildRequest(functionName, body);
    _logger.info('POST ${request.url}', context: _context);

    final client = _clientFactory();
    http.Response response;
    try {
      response = await Future(
        () async => http.Response.fromStream(await client.send(request)),
      ).timeout(_timeoutFor(body));
    } catch (e, st) {
      _logger.error(
        'Network error calling $functionName',
        context: _context,
        error: e,
        stackTrace: st,
      );
      throw VanaOfflineException(e);
    } finally {
      client.close();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) await recoverSessionAfter401();
      throw mapErrorResponse(response.statusCode, response.body);
    }

    final decoded = _tryDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw VanaServerException(
      response.statusCode,
      response.body,
      error: 'invalid_response',
    );
  }

  Future<void>? _refreshInFlight;

  /// The one refresh a 401 earns (117-011). Concurrent 401s (the eleven of
  /// the Finding) await the same attempt; a 401 that arrives after it has
  /// finished starts a new one, against whatever session is then held, so a
  /// phone whose session GoTrue just dropped finds none and does nothing.
  ///
  /// Running twice: the second caller joins the first's future. After a
  /// sign-out `_buildRequest` throws before any request, so there is no
  /// further 401 to recover from.
  @visibleForTesting
  Future<void> recoverSessionAfter401() {
    return _refreshInFlight ??= _refreshOrSignOut().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<void> _refreshOrSignOut() async {
    final auth = _supabase.auth;
    if (auth.currentSession == null) return;
    try {
      await auth.refreshSession();
      _logger.info('Session refreshed after a 401', context: _context);
    } on AuthRetryableFetchException catch (e) {
      // The refresh could not reach GoTrue: not a verdict on the session.
      _logger.warning(
        'Session refresh after a 401 could not reach the server; staying '
        'signed in',
        context: _context,
        error: e,
      );
    } on AuthException catch (e) {
      // GoTrue refused the refresh token (or there was none): the server
      // ended this session. GoTrue drops the local session itself on an
      // invalid token; the explicit sign-out covers the cases where it did
      // not, and is skipped when the session is already gone so the
      // `signedOut` event fires once.
      _logger.warning(
        'Session refresh after a 401 was refused; signing out locally',
        context: _context,
        error: e,
      );
      if (auth.currentSession != null) {
        try {
          await auth.signOut(scope: SignOutScope.local);
        } catch (signOutError) {
          _logger.warning(
            'Local sign-out after a refused refresh failed',
            context: _context,
            error: signOutError,
          );
        }
      }
    } catch (e) {
      _logger.warning(
        'Session refresh after a 401 failed; staying signed in',
        context: _context,
        error: e,
      );
    }
  }

  /// Map a non-2xx status + body to the typed exception (contract 02 §5).
  Exception mapErrorResponse(int statusCode, String body) {
    _logger.error('Vana HTTP $statusCode: $body', context: _context);
    final json = _tryDecode(body);
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final error = map['error'];
    final errorCode = error is String ? error : null;

    // The gateway refusing US is checked BEFORE the status, so it can never
    // fall into the 402 arm and raise the top-up sheet: the athlete's wallet
    // is not what ran out (mp-437).
    if (errorCode == VanaUnavailableException.code) {
      return const VanaUnavailableException();
    }

    switch (statusCode) {
      case 401:
        return VanaUnauthenticatedException(errorCode ?? 'unauthenticated');
      case 402:
        return InsufficientCreditsException.fromMap(map);
      case 403:
        return ProRequiredException(errorCode ?? 'pro_required');
      case 429:
        return VanaRateLimitedException(
          retryAfterSeconds:
              (map['retry_after_seconds'] as num?)?.toInt() ??
              (map['retryAfterSeconds'] as num?)?.toInt() ??
              10,
        );
      default:
        return VanaServerException(statusCode, body, error: errorCode);
    }
  }

  static Object? _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  /// Split a byte stream into decoded JSON objects, one per LF-terminated
  /// line. Chunks may split mid-line, so a partial tail is buffered.
  Stream<Map<String, dynamic>> _splitLines(
    Stream<List<int>> byteStream, {
    required void Function() onDone,
  }) async* {
    final buffer = StringBuffer();
    try {
      await for (final chunk in byteStream.transform(utf8.decoder)) {
        buffer.write(chunk);
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer
          ..clear()
          ..write(lines.last);
        for (var i = 0; i < lines.length - 1; i++) {
          final decoded = _decodeLine(lines[i]);
          if (decoded != null) yield decoded;
        }
      }
      final remaining = _decodeLine(buffer.toString());
      if (remaining != null) yield remaining;
    } finally {
      onDone();
    }
  }

  Map<String, dynamic>? _decodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final decoded = _tryDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    _logger.warning(
      'Skipping non-object NDJSON line',
      context: _context,
      data: {
        'line': trimmed.length > 200 ? trimmed.substring(0, 200) : trimmed,
      },
    );
    return null;
  }
}
