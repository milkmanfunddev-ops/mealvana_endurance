import 'dart:async';
import 'dart:convert';

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
class VanaTransport {
  VanaTransport({
    required SupabaseClient supabase,
    required AppConfig config,
    required AppLogger logger,
    HttpClientFactory? clientFactory,
  }) : _supabase = supabase,
       _config = config,
       _logger = logger,
       _clientFactory = clientFactory ?? http.Client.new;

  final SupabaseClient _supabase;
  final AppConfig _config;
  final AppLogger _logger;
  final HttpClientFactory _clientFactory;

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
  /// [InsufficientCreditsException] on 402) before any line is emitted.
  Future<NdjsonResponse> streamNdjson(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final request = _buildRequest(functionName, body);
    _logger.info('POST ${request.url} (stream)', context: _context);

    final client = _clientFactory();
    http.StreamedResponse streamed;
    try {
      streamed = await client.send(request);
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
      response = await http.Response.fromStream(await client.send(request));
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

  /// Map a non-2xx status + body to the typed exception (contract 02 §5).
  Exception mapErrorResponse(int statusCode, String body) {
    _logger.error('Vana HTTP $statusCode: $body', context: _context);
    final json = _tryDecode(body);
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final error = map['error'];
    final errorCode = error is String ? error : null;

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
