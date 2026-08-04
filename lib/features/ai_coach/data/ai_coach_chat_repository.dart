import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../shared/services/app_config.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/ai_coach_conversation.dart';
import '../domain/ai_coach_message.dart';
import '../domain/ai_coach_ui_part.dart';

part 'ai_coach_chat_repository.g.dart';

// ---------------------------------------------------------------------------
// Typed errors
// ---------------------------------------------------------------------------

/// Base class for Mealvana AI repository errors.
sealed class AiCoachChatError {
  const AiCoachChatError();
}

/// The device appears to be offline or the connection was refused.
class AiCoachChatOfflineError extends AiCoachChatError {
  const AiCoachChatOfflineError(this.cause);
  final Object cause;

  @override
  String toString() => 'AiCoachChatOfflineError: $cause';
}

/// The server returned a non-200 response.
class AiCoachChatServerError extends AiCoachChatError {
  const AiCoachChatServerError(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'AiCoachChatServerError($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Typed stream events
// ---------------------------------------------------------------------------

/// A discriminated-union event emitted from [AiCoachChatRepository.sendMessage].
///
/// Handlers should exhaust all subtypes. Unknown parts (new server kinds that
/// this client version does not recognise) are represented by [UiPart] whose
/// [part] field may contain a [AiCoachUiPart] subclass added in a future version —
/// or the part will simply be absent if [AiCoachUiPart.fromJson] returned null.
sealed class AiCoachStreamEvent {
  const AiCoachStreamEvent();
}

/// Incremental prose text from the assistant.
class AiCoachTextDelta extends AiCoachStreamEvent {
  const AiCoachTextDelta(this.delta);
  final String delta;
}

/// A UI-renderable part (meal cards or choice buttons) attached to the reply.
class AiCoachUiPartEvent extends AiCoachStreamEvent {
  const AiCoachUiPartEvent(this.part);
  final AiCoachUiPart part;
}

/// The stream has completed successfully.
class AiCoachDoneEvent extends AiCoachStreamEvent {
  const AiCoachDoneEvent();
}

/// The server reported an error mid-stream.
class AiCoachStreamErrorEvent extends AiCoachStreamEvent {
  const AiCoachStreamErrorEvent(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Result type for sendMessage
// ---------------------------------------------------------------------------

/// Holds the streaming response for a single send-message call.
class AiCoachSendResult {
  const AiCoachSendResult({
    required this.conversationId,
    required this.eventStream,
  });

  /// The conversation UUID from the `x-conversation-id` response header.
  final String conversationId;

  /// Stream of typed [AiCoachStreamEvent] items from the NDJSON response.
  ///
  /// The stream completes when [AiCoachDoneEvent] is received or the underlying
  /// HTTP connection closes. Errors are surfaced as [AiCoachStreamErrorEvent] or
  /// as uncaught [AiCoachChatError] exceptions.
  final Stream<AiCoachStreamEvent> eventStream;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Data-layer gateway to the Mealvana AI AI coach edge function and Supabase tables.
///
/// Responsibilities:
///   - [fetchConversations] — query `jade_conversations` (most recent first,
///     non-deleted) via the Supabase client (RLS applies).
///   - [fetchMessages] — query `jade_messages` for a conversation (ascending
///     order), also via the Supabase client. Selects `metadata` column so
///     persisted [AiCoachUiPart]s are loaded from history.
///   - [sendMessage] — stream a POST to `/functions/v1/jade-chat` using the
///     raw `http` package (the Supabase SDK does not support streaming).
///     Parses NDJSON lines and emits typed [AiCoachStreamEvent] instances.
class AiCoachChatRepository {
  AiCoachChatRepository({
    required SupabaseClient supabase,
    required AppConfig config,
    required AppLogger logger,
  }) : _supabase = supabase,
       _config = config,
       _logger = logger;

  final SupabaseClient _supabase;
  final AppConfig _config;
  final AppLogger _logger;

  // ── Conversations ──────────────────────────────────────────────────────────

  /// Returns the user's conversations ordered by `updated_at` descending.
  ///
  /// Excludes soft-deleted rows (`is_deleted = false`).
  Future<List<AiCoachConversation>> fetchConversations() async {
    try {
      final response = await _supabase
          .from('jade_conversations')
          .select('id, title, created_at, updated_at, is_deleted')
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map(
            (row) => AiCoachConversation.fromJson(row as Map<String, dynamic>),
          )
          .toList();
    } catch (e, st) {
      _logger.error(
        'AiCoachChatRepository.fetchConversations failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Returns the messages for [conversationId] ordered chronologically.
  ///
  /// Selects the `metadata` column so persisted UI parts are hydrated into
  /// [AiCoachMessage.uiParts] from `metadata.ui_parts`.
  Future<List<AiCoachMessage>> fetchMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('jade_messages')
          .select('id, conversation_id, role, content, metadata, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((row) => AiCoachMessage.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.error(
        'AiCoachChatRepository.fetchMessages($conversationId) failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── Send (streaming POST) ──────────────────────────────────────────────────

  /// Sends [message] to the jade-chat edge function and returns a
  /// [AiCoachSendResult] with the conversation id and a [AiCoachStreamEvent] stream.
  ///
  /// The server responds with `Content-Type: application/x-ndjson` — one JSON
  /// object per line. This method buffers partial lines across HTTP chunks,
  /// parses complete lines, and maps them to typed events.
  ///
  /// Pass [conversationId] to continue an existing conversation; omit to start
  /// a new one (the server will create one and surface its id via the
  /// `x-conversation-id` response header).
  ///
  /// [timezone] should be an IANA timezone string (e.g. `"America/Chicago"`).
  /// [latitude] and [longitude] are optional — the server degrades gracefully
  /// if absent.
  ///
  /// Throws [AiCoachChatOfflineError] on network failure or [AiCoachChatServerError]
  /// on non-200 responses.
  Future<AiCoachSendResult> sendMessage({
    required String message,
    String? conversationId,
    String? timezone,
    double? latitude,
    double? longitude,
  }) async {
    final bodyMap = <String, dynamic>{'message': message};
    if (conversationId != null && conversationId.isNotEmpty) {
      bodyMap['conversation_id'] = conversationId;
    }
    if (timezone != null && timezone.isNotEmpty) {
      bodyMap['timezone'] = timezone;
    }
    if (latitude != null && longitude != null) {
      bodyMap['location'] = {'latitude': latitude, 'longitude': longitude};
    }

    return _streamRequest(bodyMap, fallbackConversationId: conversationId);
  }

  // ── Opener (proactive greeting) ────────────────────────────────────────────

  /// Requests Mealvana AI's proactive opening greeting — the server generates a
  /// contextual hello (referencing upcoming workouts/races and recent logs)
  /// without a user turn. Nothing is persisted server-side: the opener is
  /// ephemeral and regenerated each time the chat is opened fresh, so the
  /// returned [AiCoachSendResult.conversationId] is empty.
  ///
  /// Throws the same [AiCoachChatError] subtypes as [sendMessage]; callers should
  /// treat failure as "no opener" and fall back to the static empty state.
  Future<AiCoachSendResult> requestOpener({
    String? timezone,
    double? latitude,
    double? longitude,
  }) async {
    final bodyMap = <String, dynamic>{'opener': true};
    if (timezone != null && timezone.isNotEmpty) {
      bodyMap['timezone'] = timezone;
    }
    if (latitude != null && longitude != null) {
      bodyMap['location'] = {'latitude': latitude, 'longitude': longitude};
    }

    return _streamRequest(bodyMap, fallbackConversationId: null);
  }

  // ── Shared streaming POST ──────────────────────────────────────────────────

  /// POSTs [bodyMap] to the jade-chat edge function and returns a
  /// [AiCoachSendResult]. Shared by [sendMessage] and [requestOpener].
  Future<AiCoachSendResult> _streamRequest(
    Map<String, dynamic> bodyMap, {
    required String? fallbackConversationId,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const AiCoachChatServerError(401, 'No active session');
    }

    final uri = Uri.parse('${_config.supabaseUrl}/functions/v1/jade-chat');

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..headers['apikey'] = _config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(bodyMap);

    _logger.info('AiCoachChatRepository._streamRequest → $uri');

    http.StreamedResponse streamed;
    try {
      streamed = await http.Client().send(request);
    } catch (e, st) {
      _logger.error(
        'AiCoachChatRepository._streamRequest network error',
        error: e,
        stackTrace: st,
      );
      throw AiCoachChatOfflineError(e);
    }

    if (streamed.statusCode != 200) {
      final responseBody = await streamed.stream.bytesToString();
      _logger.error(
        'AiCoachChatRepository._streamRequest HTTP ${streamed.statusCode}: $responseBody',
      );
      // 402 → out of AI credits. Throw the typed exception so the presentation
      // layer can route the user to the buy-credits paywall.
      if (streamed.statusCode == 402) {
        throw _insufficientCreditsFromBody(responseBody);
      }
      throw AiCoachChatServerError(streamed.statusCode, responseBody);
    }

    // The conversation id is sent in a response header (even for new
    // conversations the server sets it before streaming begins).
    final resolvedConversationId =
        streamed.headers['x-conversation-id'] ?? fallbackConversationId ?? '';

    _logger.info(
      'AiCoachChatRepository._streamRequest: conv=$resolvedConversationId streaming NDJSON',
    );

    return AiCoachSendResult(
      conversationId: resolvedConversationId,
      eventStream: _parseNdjsonStream(streamed.stream),
    );
  }

  /// Parse a jade-chat 402 body into an [InsufficientCreditsException].
  /// The body is expected to be the standard
  /// `{ error, message, balance, cost }` shape but degrades gracefully.
  InsufficientCreditsException _insufficientCreditsFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return InsufficientCreditsException.fromMap(decoded);
      }
    } catch (_) {
      // fall through to defaults
    }
    return const InsufficientCreditsException(
      balance: 0,
      cost: 0,
      message: 'Not enough AI credits.',
    );
  }

  // ── NDJSON parsing ─────────────────────────────────────────────────────────

  /// Transforms the raw HTTP byte stream into a [Stream<AiCoachStreamEvent>].
  ///
  /// Strategy:
  ///   1. Decode bytes → UTF-8 string chunks (chunks may split mid-line).
  ///   2. Buffer a partial-line tail; flush complete lines (terminated by \n).
  ///   3. Parse each complete line as JSON; map to a [AiCoachStreamEvent].
  ///   4. Unknown JSON shapes / parse failures are logged and skipped.
  Stream<AiCoachStreamEvent> _parseNdjsonStream(
    Stream<List<int>> byteStream,
  ) async* {
    final buffer = StringBuffer();

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer.write(chunk);

      // Extract all complete lines from the buffer.
      final raw = buffer.toString();
      final lines = raw.split('\n');

      // The last element is either empty (chunk ended with \n) or a partial
      // line waiting for more data. Keep it in the buffer.
      buffer.clear();
      buffer.write(lines.last);

      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final event = _parseLine(line);
        if (event != null) yield event;
      }
    }

    // Flush any remaining buffered content (should be empty or just whitespace
    // after a well-formed done event, but handle gracefully).
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      final event = _parseLine(remaining);
      if (event != null) yield event;
    }
  }

  /// Parses a single NDJSON line into a [AiCoachStreamEvent].
  ///
  /// Returns null for unrecognised or malformed lines (graceful degradation).
  AiCoachStreamEvent? _parseLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'text':
          final delta = json['delta'] as String?;
          if (delta == null) return null;
          return AiCoachTextDelta(delta);

        case 'ui':
          final partJson = json['part'];
          if (partJson is! Map<String, dynamic>) return null;
          final part = AiCoachUiPart.fromJson(partJson);
          if (part == null) return null; // unknown kind — skip
          return AiCoachUiPartEvent(part);

        case 'done':
          return const AiCoachDoneEvent();

        case 'error':
          final message = (json['message'] as String?) ?? 'Unknown error';
          _logger.error('AiCoachChatRepository: server error event: $message');
          return AiCoachStreamErrorEvent(message);

        default:
          // Future protocol additions — ignore.
          return null;
      }
    } catch (e) {
      debugPrint(
        '[AiCoachChatRepository] NDJSON parse error on line: $line — $e',
      );
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

@riverpod
AiCoachChatRepository aiCoachChatRepository(Ref ref) {
  return AiCoachChatRepository(
    supabase: ref.watch(supabaseClientProvider),
    config: ref.watch(appConfigProvider),
    logger: ref.watch(appLoggerProvider),
  );
}
