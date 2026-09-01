import 'wire_record.dart';

/// `PlanRule.day` — `mon..sun`.
enum PlanRuleDay {
  mon('mon'),
  tue('tue'),
  wed('wed'),
  thu('thu'),
  fri('fri'),
  sat('sat'),
  sun('sun');

  const PlanRuleDay(this.wire);

  final String wire;

  static PlanRuleDay? fromWire(String? value) {
    if (value == null) return null;
    for (final v in PlanRuleDay.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static PlanRuleDay requireWire(String? value) =>
      fromWire(value) ??
      (throw FormatException('Unknown PlanRuleDay "$value"'));
}

/// A proposed/accepted week rule — `PlanRule` in `contracts.ts`
/// (`{day, rule, mealId?, accepted}`).
class PlanRule extends WireRecord {
  const PlanRule({
    required this.day,
    required this.rule,
    this.mealId,
    required this.accepted,
  });

  final PlanRuleDay day;
  final String rule;
  final String? mealId;
  final bool accepted;

  factory PlanRule.fromJson(Map<String, dynamic> json) => PlanRule(
    day: PlanRuleDay.requireWire(readString(json, 'day')),
    rule: readString(json, 'rule') ?? '',
    mealId: readString(json, 'mealId'),
    accepted: readBool(json, 'accepted') ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {
    'day': day.wire,
    'rule': rule,
    if (mealId != null) 'mealId': mealId,
    'accepted': accepted,
  };

  PlanRule copyWith({
    PlanRuleDay? day,
    String? rule,
    String? mealId,
    bool? accepted,
  }) => PlanRule(
    day: day ?? this.day,
    rule: rule ?? this.rule,
    mealId: mealId ?? this.mealId,
    accepted: accepted ?? this.accepted,
  );
}
