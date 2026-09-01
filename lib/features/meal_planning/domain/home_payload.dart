import 'athlete_context.dart';
import 'day_plan.dart';
import 'day_target.dart';
import 'user_memory.dart';
import 'vana_part.dart';
import 'wire_record.dart';

/// The `home` object returned by the `get_home` action (prototype
/// `homePayload()`): everything the Food → Plan screen needs in one call, no
/// model involved. The envelope is `{parts: [batch?], home: HomePayload}`.
class HomePayload extends WireRecord {
  const HomePayload({
    required this.context,
    this.brief,
    required this.day,
    this.target,
    this.weekTargets = const [],
    this.staples,
    this.batch,
    this.shopping,
    required this.days,
    required this.vana,
    this.memories = const [],
  });

  final AthleteContext context;

  /// Always `null` from the prototype today (legacy weekly brief slot).
  final String? brief;

  /// Today's deterministic day card.
  final VanaDayGuidancePart day;

  /// The requested date's budget, if the macro service has one.
  final DayTarget? target;
  final List<DayTarget> weekTargets;

  /// Suggested staples — only when there is no plan (or it is empty).
  final VanaStaplesPart? staples;

  /// The week's active plan, or `null` when there is none.
  final VanaBatchPart? batch;

  /// The plan's shopping list, or `null` when there is no plan.
  final VanaShoppingListPart? shopping;

  /// The day-planner slots for the requested date.
  final HomeDays days;

  /// Vana's message for the day.
  final HomeVanaNote vana;
  final List<UserMemory> memories;

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
    context: AthleteContext.fromJson(requireJsonMap(json, 'context')),
    brief: readString(json, 'brief'),
    day: VanaDayGuidancePart.fromJson(requireJsonMap(json, 'day')),
    target: switch (asJsonMap(json['target'])) {
      final map? => DayTarget.fromJson(map),
      null => null,
    },
    weekTargets: readRecordList(json, 'weekTargets', DayTarget.fromJson),
    staples: switch (asJsonMap(json['staples'])) {
      final map? => VanaStaplesPart.fromJson(map),
      null => null,
    },
    batch: switch (asJsonMap(json['batch'])) {
      final map? => VanaBatchPart.fromJson(map),
      null => null,
    },
    shopping: switch (asJsonMap(json['shopping'])) {
      final map? => VanaShoppingListPart.fromJson(map),
      null => null,
    },
    days: HomeDays.fromJson(asJsonMap(json['days']) ?? const {}),
    vana: HomeVanaNote.fromJson(asJsonMap(json['vana']) ?? const {}),
    memories: readRecordList(json, 'memories', UserMemory.fromJson),
  );

  @override
  Map<String, dynamic> toJson() => {
    'context': context.toJson(),
    'brief': brief,
    'day': day.toJson(),
    'target': target?.toJson(),
    'weekTargets': weekTargets.map((t) => t.toJson()).toList(),
    'staples': staples?.toJson(),
    'batch': batch?.toJson(),
    'shopping': shopping?.toJson(),
    'days': days.toJson(),
    'vana': vana.toJson(),
    'memories': memories.map((m) => m.toJson()).toList(),
  };

  HomePayload copyWith({
    AthleteContext? context,
    String? brief,
    VanaDayGuidancePart? day,
    DayTarget? target,
    List<DayTarget>? weekTargets,
    VanaStaplesPart? staples,
    VanaBatchPart? batch,
    VanaShoppingListPart? shopping,
    HomeDays? days,
    HomeVanaNote? vana,
    List<UserMemory>? memories,
  }) => HomePayload(
    context: context ?? this.context,
    brief: brief ?? this.brief,
    day: day ?? this.day,
    target: target ?? this.target,
    weekTargets: weekTargets ?? this.weekTargets,
    staples: staples ?? this.staples,
    batch: batch ?? this.batch,
    shopping: shopping ?? this.shopping,
    days: days ?? this.days,
    vana: vana ?? this.vana,
    memories: memories ?? this.memories,
  );
}

/// `home.days` — `{date, slots: DayPlan}`.
class HomeDays extends WireRecord {
  const HomeDays({required this.date, this.slots = DayPlan.empty});

  final String date;
  final DayPlan slots;

  factory HomeDays.fromJson(Map<String, dynamic> json) => HomeDays(
    date: readString(json, 'date') ?? '',
    slots: DayPlan.fromJson(asJsonMap(json['slots']) ?? const {}),
  );

  @override
  Map<String, dynamic> toJson() => {'date': date, 'slots': slots.toJson()};

  HomeDays copyWith({String? date, DayPlan? slots}) =>
      HomeDays(date: date ?? this.date, slots: slots ?? this.slots);
}

/// `home.vana` — the day note. When [stale] the server is regenerating
/// notes; the client re-polls `get_home` after ~7 s (never generates).
class HomeVanaNote extends WireRecord {
  const HomeVanaNote({required this.date, this.stale = false, this.text});

  final String date;
  final bool stale;
  final String? text;

  factory HomeVanaNote.fromJson(Map<String, dynamic> json) => HomeVanaNote(
    date: readString(json, 'date') ?? '',
    stale: readBool(json, 'stale') ?? false,
    text: readString(json, 'text'),
  );

  @override
  Map<String, dynamic> toJson() => {'date': date, 'stale': stale, 'text': text};

  HomeVanaNote copyWith({String? date, bool? stale, String? text}) =>
      HomeVanaNote(
        date: date ?? this.date,
        stale: stale ?? this.stale,
        text: text ?? this.text,
      );
}
