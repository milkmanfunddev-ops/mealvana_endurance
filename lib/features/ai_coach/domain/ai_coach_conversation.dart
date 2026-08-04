/// Domain model for a Jade AI coach conversation.
///
/// Maps to the `jade_conversations` Supabase table (read via RLS — the
/// client never inserts; the edge function creates rows server-side).
class JadeConversation {
  const JadeConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  factory JadeConversation.fromJson(Map<String, dynamic> json) {
    return JadeConversation(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'JadeConversation(id: $id, title: $title, updatedAt: $updatedAt)';
}
