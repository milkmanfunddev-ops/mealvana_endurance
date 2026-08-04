import 'ai_coach_ui_part.dart';

/// Role of a message participant in a Mealvana AI conversation.
enum AiCoachMessageRole {
  user,
  assistant;

  static AiCoachMessageRole fromString(String value) {
    return switch (value) {
      'user' => AiCoachMessageRole.user,
      'assistant' => AiCoachMessageRole.assistant,
      _ => AiCoachMessageRole.user,
    };
  }
}

/// Domain model for a single message in a Mealvana AI AI coach conversation.
///
/// Maps to the `jade_messages` Supabase table (read via RLS — the client
/// never inserts; the edge function persists both sides).
///
/// [uiParts] is populated from `metadata.ui_parts` (jsonb) when loading
/// history, and accumulated live from the NDJSON stream during the current
/// session.
class AiCoachMessage {
  const AiCoachMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.uiParts = const [],
  });

  final String id;
  final String conversationId;
  final AiCoachMessageRole role;

  /// The text content of the message.
  ///
  /// For in-flight assistant messages this is accumulated incrementally as
  /// streaming chunks arrive; [isStreaming] on [AiCoachChatState] marks when
  /// accumulation is in progress.
  final String content;

  final DateTime createdAt;

  /// UI parts attached to this message (meal cards, choice buttons, etc.).
  ///
  /// For persisted messages these come from `metadata.ui_parts`.
  /// For the in-flight streaming message they are accumulated live.
  final List<AiCoachUiPart> uiParts;

  factory AiCoachMessage.fromJson(Map<String, dynamic> json) {
    // Parse ui_parts from metadata.ui_parts (jsonb).
    final uiParts = <AiCoachUiPart>[];
    try {
      final metadata = json['metadata'];
      if (metadata is Map<String, dynamic>) {
        final rawParts = metadata['ui_parts'];
        if (rawParts is List) {
          for (final p in rawParts) {
            if (p is Map<String, dynamic>) {
              final part = AiCoachUiPart.fromJson(p);
              if (part != null) uiParts.add(part);
            }
          }
        }
      }
    } catch (_) {
      // Malformed metadata — silently ignore; uiParts stays empty.
    }

    return AiCoachMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: AiCoachMessageRole.fromString(json['role'] as String),
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      uiParts: uiParts,
    );
  }

  /// Returns a copy with the given [content] applied (used during streaming).
  AiCoachMessage copyWithContent(String content) {
    return AiCoachMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      uiParts: uiParts,
    );
  }

  /// Returns a copy with a new [AiCoachUiPart] appended.
  AiCoachMessage copyWithUiPart(AiCoachUiPart part) {
    return AiCoachMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      uiParts: [...uiParts, part],
    );
  }

  @override
  String toString() =>
      'AiCoachMessage(id: $id, role: ${role.name}, content: ${content.length}ch, '
      'uiParts: ${uiParts.length})';
}
