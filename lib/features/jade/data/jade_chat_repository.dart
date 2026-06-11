import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/jade_conversation.dart';
import '../domain/jade_message.dart';

part 'jade_chat_repository.g.dart';

// ---------------------------------------------------------------------------
// Typed errors
// ---------------------------------------------------------------------------

/// Base class for Jade repository errors.
sealed class JadeChatError {
  const JadeChatError();
}

/// The device appears to be offline or the connection was refused.
class JadeChatOfflineError extends JadeChatError {
  const JadeChatOfflineError(this.cause);
  final Object cause;

  @override
  String toString() => 'JadeChatOfflineError: $cause';
}

/// The server returned a non-200 response.
class JadeChatServerError extends JadeChatError {
  const JadeChatServerError(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'JadeChatServerError($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Result type for sendMessage
// ---------------------------------------------------------------------------

/// Holds the streaming response for a single send-message call.
class JadeSendResult {
  const JadeSendResult({
    required this.conversationId,
    required this.textStream,
  });

  /// The conversation UUID from the `x-conversation-id` response header.
  final String conversationId;

  /// Stream of incremental text chunks from the edge function.
  ///
  /// The stream completes when the server closes the response body. Errors
  /// emitted here are already [JadeChatError] typed.
  final Stream<String> textStream;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Data-layer gateway to the Jade AI coach edge function and Supabase tables.
///
/// Responsibilities:
///   - [fetchConversations] — query `jade_conversations` (most recent first,
///     non-deleted) via the Supabase client (RLS applies).
///   - [fetchMessages] — query `jade_messages` for a conversation (ascending
///     order), also via the Supabase client.
///   - [sendMessage] — stream a POST to `/functions/v1/jade-chat` using the
///     raw `http` package (the Supabase SDK does not support streaming).
class JadeChatRepository {
  JadeChatRepository({
    required SupabaseClient supabase,
    required AppConfig config,
    required AppLogger logger,
  })  : _supabase = supabase,
        _config = config,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppConfig _config;
  final AppLogger _logger;

  // ── Conversations ──────────────────────────────────────────────────────────

  /// Returns the user's conversations ordered by `updated_at` descending.
  ///
  /// Excludes soft-deleted rows (`is_deleted = false`).
  Future<List<JadeConversation>> fetchConversations() async {
    try {
      final response = await _supabase
          .from('jade_conversations')
          .select('id, title, created_at, updated_at, is_deleted')
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map((row) => JadeConversation.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.error(
        'JadeChatRepository.fetchConversations failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Returns the messages for [conversationId] ordered chronologically.
  Future<List<JadeMessage>> fetchMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('jade_messages')
          .select('id, conversation_id, role, content, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((row) => JadeMessage.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.error(
        'JadeChatRepository.fetchMessages($conversationId) failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ── Send (streaming POST) ──────────────────────────────────────────────────

  /// Sends [message] to the jade-chat edge function and returns a
  /// [JadeSendResult] with the conversation id and an incremental text stream.
  ///
  /// Pass [conversationId] to continue an existing conversation; omit to start
  /// a new one (the server will create one and surface its id via the
  /// `x-conversation-id` response header).
  ///
  /// [timezone] should be an IANA timezone string (e.g. `"America/Chicago"`).
  /// [latitude] and [longitude] are optional — the server degrades gracefully
  /// if absent.
  ///
  /// Throws [JadeChatOfflineError] on network failure or [JadeChatServerError]
  /// on non-200 responses.
  Future<JadeSendResult> sendMessage({
    required String message,
    String? conversationId,
    String? timezone,
    double? latitude,
    double? longitude,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const JadeChatServerError(401, 'No active session');
    }

    final uri = Uri.parse(
      '${_config.supabaseUrl}/functions/v1/jade-chat',
    );

    final body = <String, dynamic>{'message': message};
    if (conversationId != null && conversationId.isNotEmpty) {
      body['conversation_id'] = conversationId;
    }
    if (timezone != null && timezone.isNotEmpty) {
      body['timezone'] = timezone;
    }
    if (latitude != null && longitude != null) {
      body['location'] = {'latitude': latitude, 'longitude': longitude};
    }

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..headers['apikey'] = _config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);

    _logger.info('JadeChatRepository.sendMessage → $uri');

    http.StreamedResponse streamed;
    try {
      streamed = await http.Client().send(request);
    } catch (e, st) {
      _logger.error(
        'JadeChatRepository.sendMessage network error',
        error: e,
        stackTrace: st,
      );
      throw JadeChatOfflineError(e);
    }

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      _logger.error(
        'JadeChatRepository.sendMessage HTTP ${streamed.statusCode}: $body',
      );
      throw JadeChatServerError(streamed.statusCode, body);
    }

    // The conversation id is sent in a response header (even for new
    // conversations the server sets it before streaming begins).
    final resolvedConversationId =
        streamed.headers['x-conversation-id'] ?? conversationId ?? '';

    _logger.info(
      'JadeChatRepository.sendMessage: conv=$resolvedConversationId streaming',
    );

    // Transform raw bytes → UTF-8 text chunks, propagating errors as
    // JadeChatServerError so the controller can handle them uniformly.
    final textStream = streamed.stream
        .transform(utf8.decoder)
        .handleError((Object e, StackTrace st) {
      _logger.error('JadeChatRepository stream error', error: e, stackTrace: st);
      throw JadeChatServerError(0, e.toString());
    });

    return JadeSendResult(
      conversationId: resolvedConversationId,
      textStream: textStream,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

@riverpod
JadeChatRepository jadeChatRepository(Ref ref) {
  return JadeChatRepository(
    supabase: ref.watch(supabaseClientProvider),
    config: ref.watch(appConfigProvider),
    logger: ref.watch(appLoggerProvider),
  );
}
