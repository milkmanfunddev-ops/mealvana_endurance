import 'jade_ui_part.dart';

/// Role of a message participant in a Jade conversation.
enum JadeMessageRole {
  user,
  assistant;

  static JadeMessageRole fromString(String value) {
    return switch (value) {
      'user' => JadeMessageRole.user,
      'assistant' => JadeMessageRole.assistant,
      _ => JadeMessageRole.user,
    };
  }
}

/// Domain model for a single message in a Jade AI coach conversation.
///
/// Maps to the `jade_messages` Supabase table (read via RLS — the client
/// never inserts; the edge function persists both sides).
///
/// [uiParts] is populated from `metadata.ui_parts` (jsonb) when loading
/// history, and accumulated live from the NDJSON stream during the current
/// session.
class JadeMessage {
  const JadeMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.uiParts = const [],
  });

  final String id;
  final String conversationId;
  final JadeMessageRole role;

  /// The text content of the message.
  ///
  /// For in-flight assistant messages this is accumulated incrementally as
  /// streaming chunks arrive; [isStreaming] on [JadeChatState] marks when
  /// accumulation is in progress.
  final String content;

  final DateTime createdAt;

  /// UI parts attached to this message (meal cards, choice buttons, etc.).
  ///
  /// For persisted messages these come from `metadata.ui_parts`.
  /// For the in-flight streaming message they are accumulated live.
  final List<JadeUiPart> uiParts;

  factory JadeMessage.fromJson(Map<String, dynamic> json) {
    // Parse ui_parts from metadata.ui_parts (jsonb).
    final uiParts = <JadeUiPart>[];
    try {
      final metadata = json['metadata'];
      if (metadata is Map<String, dynamic>) {
        final rawParts = metadata['ui_parts'];
        if (rawParts is List) {
          for (final p in rawParts) {
            if (p is Map<String, dynamic>) {
              final part = JadeUiPart.fromJson(p);
              if (part != null) uiParts.add(part);
            }
          }
        }
      }
    } catch (_) {
      // Malformed metadata — silently ignore; uiParts stays empty.
    }

    return JadeMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: JadeMessageRole.fromString(json['role'] as String),
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      uiParts: uiParts,
    );
  }

  /// Returns a copy with the given [content] applied (used during streaming).
  JadeMessage copyWithContent(String content) {
    return JadeMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      uiParts: uiParts,
    );
  }

  /// Returns a copy with a new [JadeUiPart] appended.
  JadeMessage copyWithUiPart(JadeUiPart part) {
    return JadeMessage(
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
      'JadeMessage(id: $id, role: ${role.name}, content: ${content.length}ch, '
      'uiParts: ${uiParts.length})';
}
