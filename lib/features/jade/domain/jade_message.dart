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
class JadeMessage {
  const JadeMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
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

  factory JadeMessage.fromJson(Map<String, dynamic> json) {
    return JadeMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      role: JadeMessageRole.fromString(json['role'] as String),
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
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
    );
  }

  @override
  String toString() =>
      'JadeMessage(id: $id, role: ${role.name}, content: ${content.length}ch)';
}
