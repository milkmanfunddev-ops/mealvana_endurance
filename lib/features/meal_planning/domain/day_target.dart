import 'wire_record.dart';

/// One day's budget — `DayTarget` in `contracts.ts`. Comes straight from
/// `daily_macro_targets` on the server; never recomputed client-side.
class DayTarget extends WireRecord {
  const DayTarget({
    required this.date,
    required this.kcal,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sessionKcal,
    required this.planningKcal,
    required this.lunchDinnerKcal,
    this.mode,
  });

  /// `YYYY-MM-DD`.
  final String date;
  final int kcal;
  final int carbsG;
  final int proteinG;
  final int fatG;

  /// Energy attributed to the day's session(s).
  final int sessionKcal;

  /// What the planner budgets against.
  final int planningKcal;

  /// The lunch + dinner share of [planningKcal].
  final int lunchDinnerKcal;

  /// Day mode label from the macro service (e.g. rest / training), if any.
  final String? mode;

  factory DayTarget.fromJson(Map<String, dynamic> json) => DayTarget(
    date: requireString(json, 'date'),
    kcal: readInt(json, 'kcal') ?? 0,
    carbsG: readInt(json, 'carbsG') ?? 0,
    proteinG: readInt(json, 'proteinG') ?? 0,
    fatG: readInt(json, 'fatG') ?? 0,
    sessionKcal: readInt(json, 'sessionKcal') ?? 0,
    planningKcal: readInt(json, 'planningKcal') ?? 0,
    lunchDinnerKcal: readInt(json, 'lunchDinnerKcal') ?? 0,
    mode: readString(json, 'mode'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'date': date,
    'kcal': kcal,
    'carbsG': carbsG,
    'proteinG': proteinG,
    'fatG': fatG,
    'sessionKcal': sessionKcal,
    'planningKcal': planningKcal,
    'lunchDinnerKcal': lunchDinnerKcal,
    'mode': mode,
  };

  DayTarget copyWith({
    String? date,
    int? kcal,
    int? carbsG,
    int? proteinG,
    int? fatG,
    int? sessionKcal,
    int? planningKcal,
    int? lunchDinnerKcal,
    String? mode,
  }) => DayTarget(
    date: date ?? this.date,
    kcal: kcal ?? this.kcal,
    carbsG: carbsG ?? this.carbsG,
    proteinG: proteinG ?? this.proteinG,
    fatG: fatG ?? this.fatG,
    sessionKcal: sessionKcal ?? this.sessionKcal,
    planningKcal: planningKcal ?? this.planningKcal,
    lunchDinnerKcal: lunchDinnerKcal ?? this.lunchDinnerKcal,
    mode: mode ?? this.mode,
  );
}
