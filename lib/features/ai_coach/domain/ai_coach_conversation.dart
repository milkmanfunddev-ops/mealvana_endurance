/// Domain model for a Mealvana AI AI coach conversation.
///
/// Maps to the `jade_conversations` Supabase table (read via RLS — the
/// client never inserts; the edge function creates rows server-side).
class AiCoachConversation {
  const AiCoachConversation({
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

  factory AiCoachConversation.fromJson(Map<String, dynamic> json) {
    return AiCoachConversation(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }

  @override
  String toString() =>
      'AiCoachConversation(id: $id, title: $title, updatedAt: $updatedAt)';
}
