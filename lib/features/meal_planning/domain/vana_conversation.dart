import 'meal_plan_status.dart';
import 'vana_conversation_kind.dart';
import 'wire_record.dart';

/// The plan a meal-plan conversation holds — `ConversationPlan` in
/// `contracts.ts`: its week, state and meal count, which title the row
/// ("Sep 20 week · Draft", testing-wave 97). The server picks the confirmed
/// plan when the conversation has one, else the newest with meals.
class VanaConversationPlan {
  const VanaConversationPlan({
    required this.weekStart,
    required this.status,
    this.mealCount = 0,
  });

  /// `YYYY-MM-DD`, the first day of the plan's period.
  final String weekStart;
  final MealPlanStatus status;
  final int mealCount;

  factory VanaConversationPlan.fromJson(Map<String, dynamic> json) =>
      VanaConversationPlan(
        weekStart: requireString(json, 'weekStart'),
        status: MealPlanStatus.requireWire(readString(json, 'status')),
        mealCount: readInt(json, 'mealCount') ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart,
    'status': status.wire,
    'mealCount': mealCount,
  };
}

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
    this.plan,
  });

  final String id;
  final VanaConversationKind kind;
  final String? title;
  final String? summary;

  /// ISO timestamps as sent.
  final String? lastMessageAt;
  final String createdAt;

  /// The plan this conversation holds; `null` for a general conversation
  /// or a planning one that never built anything.
  final VanaConversationPlan? plan;

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
        plan: switch (asJsonMap(json['plan'])) {
          final Map<String, dynamic> plan => VanaConversationPlan.fromJson(
            plan,
          ),
          null => null,
        },
      );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wire,
    'title': title,
    'summary': summary,
    'lastMessageAt': lastMessageAt,
    'createdAt': createdAt,
    'plan': plan?.toJson(),
  };

  VanaConversationSummary copyWith({
    String? id,
    VanaConversationKind? kind,
    String? title,
    String? summary,
    String? lastMessageAt,
    String? createdAt,
    VanaConversationPlan? plan,
  }) => VanaConversationSummary(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    createdAt: createdAt ?? this.createdAt,
    plan: plan ?? this.plan,
  );
}
