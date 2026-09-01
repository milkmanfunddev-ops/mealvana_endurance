import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_config.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/vana_conversation.dart';
import '../domain/vana_conversation_kind.dart';
import '../domain/vana_message.dart';
import '../domain/vana_part.dart';
import '../domain/vana_stream_event.dart';
import '../domain/wire_record.dart';
import 'vana_exceptions.dart';
import 'vana_transport.dart';

part 'vana_chat_repository.g.dart';

/// Shared transport (auth headers, error mapping, NDJSON splitting). Reads
/// its Supabase client from [appExternalDepsProvider] — the seam the
/// widget-test harness mocks.
@riverpod
VanaTransport vanaTransport(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return VanaTransport(
    supabase: deps.supabaseClient,
    config: ref.watch(appConfigProvider),
    logger: deps.logger,
  );
}

/// The Vana chat client against `vana-chat` (planning + general).
@riverpod
VanaChatRepository vanaChatRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return VanaChatRepository(
    transport: ref.watch(vanaTransportProvider),
    supabase: deps.supabaseClient,
    logger: deps.logger,
    functionName: 'vana-chat',
  );
}

/// One streaming turn: the conversation id the server assigned (from the
/// `x-conversation-id` header) plus the typed event stream.
class VanaChatResponse {
  const VanaChatResponse({
    required this.conversationId,
    required this.kind,
    required this.events,
  });

  /// `x-conversation-id` — set before the first byte, even for a brand-new
  /// conversation. Empty only if the server omitted it.
  final String conversationId;

  /// `x-vana-kind`, or the requested kind when the header is absent.
  final VanaConversationKind kind;

  /// Typed NDJSON events. Unknown line types / part kinds are dropped
  /// ([VanaStreamEvent.fromJson]). Completes after `done` or when the
  /// connection closes.
  final Stream<VanaStreamEvent> events;
}

/// Data-layer gateway to the Vana chat: streaming turns against an NDJSON
/// edge function plus the `vana_conversations` / `vana_messages` history
/// tables (read via RLS; the edge function persists both sides of a turn).
///
/// Generalized from `ai_coach/data/ai_coach_chat_repository.dart` — that
/// repository now delegates its transport here with `functionName:
/// 'jade-chat'` (see [streamRaw]).
///
/// Wire protocol: contract 02 §5. Errors: `vana_exceptions.dart`.
class VanaChatRepository {
  VanaChatRepository({
    required VanaTransport transport,
    required SupabaseClient supabase,
    required AppLogger logger,
    required this.functionName,
  }) : _transport = transport,
       _supabase = supabase,
       _logger = logger;

  final VanaTransport _transport;
  final SupabaseClient _supabase;
  final AppLogger _logger;

  /// `vana-chat` (Vana) or `jade-chat` (legacy 1.23.x alias).
  final String functionName;

  static const _context = 'VANA_CHAT_REPOSITORY';

  // ── Streaming ──────────────────────────────────────────────────────────────

  /// Stream one turn. Pass [message] for a user turn, [opener] = true for the
  /// scripted first turn (planning) / proactive greeting (general). Omit
  /// [conversationId] to let the server create the conversation.
  ///
  /// [anchorDate] (`YYYY-MM-DD`) pins the week the planning persona builds.
  ///
  /// Throws [VanaUnauthenticatedException], [ProRequiredException],
  /// [VanaRateLimitedException], [VanaOfflineException],
  /// [VanaServerException] (and `InsufficientCreditsException` on
  /// `jade-chat`) before any event is emitted.
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
  }) async {
    final body = <String, dynamic>{
      'kind': kind.wire,
      if (message != null && message.isNotEmpty) 'message': message,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id': conversationId,
      if (opener) 'opener': true,
      if (anchorDate != null) 'anchor_date': anchorDate,
      'timezone': timezone ?? resolveTimezone(),
    };

    final response = await _transport.streamNdjson(functionName, body);
    final resolvedId = response.conversationId ?? conversationId ?? '';
    final resolvedKind =
        VanaConversationKind.fromWire(response.headers['x-vana-kind']) ?? kind;

    _logger.info(
      'streamChat conv=$resolvedId kind=${resolvedKind.wire}',
      context: _context,
    );

    return VanaChatResponse(
      conversationId: resolvedId,
      kind: resolvedKind,
      events: response.lines
          .map(VanaStreamEvent.fromJson)
          .where((e) => e != null)
          .cast<VanaStreamEvent>(),
    );
  }

  /// Transport-level stream for callers with their own line parser (the
  /// legacy `AiCoachChatRepository`, whose part kinds differ from Vana's).
  Future<NdjsonResponse> streamRaw(Map<String, dynamic> body) =>
      _transport.streamNdjson(functionName, body);

  // ── Conversations ──────────────────────────────────────────────────────────

  /// The user's conversations of [kind], most recent activity first.
  Future<List<VanaConversationSummary>> fetchConversations(
    VanaConversationKind kind, {
    int limit = 50,
  }) async {
    try {
      final rows = await _supabase
          .from('vana_conversations')
          .select('id, kind, title, summary, last_message_at, created_at')
          .eq('kind', kind.wire)
          .eq('is_deleted', false)
          .order('last_message_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final row in rows as List<dynamic>)
          if (asJsonMap(row) case final map?)
            if (_conversationFromRow(map) case final c?) c,
      ];
    } catch (e, st) {
      _logger.error(
        'fetchConversations(${kind.wire}) failed',
        context: _context,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Insert an empty conversation of [kind] and return its id. RLS: owner
  /// insert (`Users manage own vana conversations`).
  Future<String> createConversation(VanaConversationKind kind) async {
    final userId = _transport.currentUserId;
    if (userId == null) throw const VanaUnauthenticatedException();
    final row = await _supabase
        .from('vana_conversations')
        .insert({
          'user_id': userId,
          'kind': kind.wire,
          'title': null,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Chronological history for [conversationId]. Assistant rows are read from
  /// `parts` (AI SDK UI parts: `text` + `tool-*` with `output` = VanaPart)
  /// and fall back to `content + metadata.ui_parts` for pre-`parts` rows.
  Future<List<VanaMessage>> fetchMessages(String conversationId) async {
    try {
      final rows = await _supabase
          .from('vana_messages')
          .select(
            'id, conversation_id, role, content, metadata, parts, created_at',
          )
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return [
        for (final row in rows as List<dynamic>)
          if (asJsonMap(row) case final map?)
            if (messageFromRow(map) case final m?) m,
      ];
    } catch (e, st) {
      _logger.error(
        'fetchMessages($conversationId) failed',
        context: _context,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Row → [VanaMessage]. Public for the parser test; returns null when the
  /// row has no usable id/role.
  static VanaMessage? messageFromRow(Map<String, dynamic> row) {
    final id = readString(row, 'id');
    final role = VanaMessageRole.fromWire(readString(row, 'role'));
    if (id == null || role == null) return null;

    final createdAt =
        DateTime.tryParse(readString(row, 'created_at') ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final content = readString(row, 'content') ?? '';

    if (role == VanaMessageRole.user) {
      return VanaMessage(
        id: id,
        conversationId: readString(row, 'conversation_id') ?? '',
        role: role,
        content: content,
        createdAt: createdAt,
      );
    }

    final rawParts = row['parts'];
    final String text;
    final List<VanaPart> parts;
    if (rawParts is List && rawParts.isNotEmpty) {
      final textBlocks = <String>[];
      final ui = <VanaPart>[];
      for (final item in rawParts) {
        final part = asJsonMap(item);
        if (part == null) continue;
        final type = readString(part, 'type') ?? '';
        if (type == 'text') {
          final t = readString(part, 'text') ?? '';
          if (t.isNotEmpty) textBlocks.add(t);
        } else if (type.startsWith('tool-') || type == 'dynamic-tool') {
          final output = asJsonMap(part['output']);
          if (output == null) continue;
          final parsed = VanaPart.fromJson(output);
          if (parsed != null) ui.add(parsed);
        }
      }
      text = textBlocks.isEmpty ? content : textBlocks.join('\n');
      parts = ui;
    } else {
      final metadata = asJsonMap(row['metadata']) ?? const <String, dynamic>{};
      text = content;
      parts = VanaPart.listFromJson(metadata['ui_parts']);
    }

    return VanaMessage(
      id: id,
      conversationId: readString(row, 'conversation_id') ?? '',
      role: role,
      content: text,
      parts: parts,
      createdAt: createdAt,
    );
  }

  static VanaConversationSummary? _conversationFromRow(
    Map<String, dynamic> row,
  ) {
    final id = readString(row, 'id');
    final kind = VanaConversationKind.fromWire(readString(row, 'kind'));
    if (id == null || kind == null) return null;
    return VanaConversationSummary(
      id: id,
      kind: kind,
      title: readString(row, 'title'),
      summary: readString(row, 'summary'),
      lastMessageAt: readString(row, 'last_message_at'),
      createdAt: readString(row, 'created_at') ?? '',
    );
  }

  // ── Timezone ───────────────────────────────────────────────────────────────

  /// The device's IANA timezone when determinable, else an offset-derived
  /// `Etc/GMT±N` zone so the server's day-boundary math tracks the local day
  /// (same rule as the legacy coach controller).
  static String resolveTimezone([DateTime? now]) {
    final at = now ?? DateTime.now();
    if (at.timeZoneName.contains('/')) return at.timeZoneName;
    final offsetHours = at.timeZoneOffset.inHours;
    if (offsetHours == 0) return 'UTC';
    // Etc/GMT zones use inverted sign by POSIX convention: UTC+5 → Etc/GMT-5.
    return offsetHours > 0 ? 'Etc/GMT-$offsetHours' : 'Etc/GMT+${-offsetHours}';
  }
}
