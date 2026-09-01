import 'vana_conversation_kind.dart';
import 'wire_record.dart';

/// A `vana_conversations` row for list screens — `ConversationSummary` in
/// `contracts.ts`.
class VanaConversationSummary extends WireRecord {
  const VanaConversationSummary({
    required this.id,
    required this.kind,
    this.title,
    this.summary,
    this.lastMessageAt,
    required this.createdAt,
  });

  final String id;
  final VanaConversationKind kind;
  final String? title;
  final String? summary;

  /// ISO timestamps as sent.
  final String? lastMessageAt;
  final String createdAt;

  DateTime? get lastMessageAtDateTime =>
      lastMessageAt == null ? null : DateTime.tryParse(lastMessageAt!);
  DateTime? get createdAtDateTime => DateTime.tryParse(createdAt);

  factory VanaConversationSummary.fromJson(Map<String, dynamic> json) =>
      VanaConversationSummary(
        id: requireString(json, 'id'),
        kind: VanaConversationKind.requireWire(readString(json, 'kind')),
        title: readString(json, 'title'),
        summary: readString(json, 'summary'),
        lastMessageAt: readString(json, 'lastMessageAt'),
        createdAt: readString(json, 'createdAt') ?? '',
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wire,
    'title': title,
    'summary': summary,
    'lastMessageAt': lastMessageAt,
    'createdAt': createdAt,
  };

  VanaConversationSummary copyWith({
    String? id,
    VanaConversationKind? kind,
    String? title,
    String? summary,
    String? lastMessageAt,
    String? createdAt,
  }) => VanaConversationSummary(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    createdAt: createdAt ?? this.createdAt,
  );
}
