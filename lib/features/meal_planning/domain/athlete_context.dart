import 'day_target.dart';
import 'user_memory.dart';
import 'wire_record.dart';

/// `AthleteContext` in `contracts.ts` — the deterministic per-turn context
/// the server injects for the model. Contract 02 §2 calls it server-internal,
/// but `get_home` returns it verbatim as `home.context` (see `home.json`), so
/// the client models it read-only. Nothing here is recomputed client-side.
class AthleteContext extends WireRecord {
  const AthleteContext({
    required this.profile,
    required this.week,
    this.race,
    required this.budget,
    required this.weather,
    this.holidays = const [],
    required this.loggedToday,
    required this.plan,
    this.memories = const [],
  });

  final AthleteProfileContext profile;
  final AthleteWeekContext week;
  final AthleteRaceContext? race;
  final AthleteBudgetContext budget;
  final AthleteWeatherContext weather;
  final List<AthleteHoliday> holidays;
  final AthleteLoggedToday loggedToday;
  final AthletePlanContext plan;

  /// Top ~10 by recency/relevance.
  final List<UserMemory> memories;

  factory AthleteContext.fromJson(Map<String, dynamic> json) => AthleteContext(
    profile: AthleteProfileContext.fromJson(
      asJsonMap(json['profile']) ?? const {},
    ),
    week: AthleteWeekContext.fromJson(asJsonMap(json['week']) ?? const {}),
    race: switch (asJsonMap(json['race'])) {
      final map? => AthleteRaceContext.fromJson(map),
      null => null,
    },
    budget: AthleteBudgetContext.fromJson(
      asJsonMap(json['budget']) ?? const {},
    ),
    weather: AthleteWeatherContext.fromJson(
      asJsonMap(json['weather']) ?? const {},
    ),
    holidays: readRecordList(json, 'holidays', AthleteHoliday.fromJson),
    loggedToday: AthleteLoggedToday.fromJson(
      asJsonMap(json['loggedToday']) ?? const {},
    ),
    plan: AthletePlanContext.fromJson(asJsonMap(json['plan']) ?? const {}),
    memories: readRecordList(json, 'memories', UserMemory.fromJson),
  );

  @override
  Map<String, dynamic> toJson() => {
    'profile': profile.toJson(),
    'week': week.toJson(),
    'race': race?.toJson(),
    'budget': budget.toJson(),
    'weather': weather.toJson(),
    'holidays': holidays.map((h) => h.toJson()).toList(),
    'loggedToday': loggedToday.toJson(),
    'plan': plan.toJson(),
    'memories': memories.map((m) => m.toJson()).toList(),
  };

  AthleteContext copyWith({
    AthleteProfileContext? profile,
    AthleteWeekContext? week,
    AthleteRaceContext? race,
    AthleteBudgetContext? budget,
    AthleteWeatherContext? weather,
    List<AthleteHoliday>? holidays,
    AthleteLoggedToday? loggedToday,
    AthletePlanContext? plan,
    List<UserMemory>? memories,
  }) => AthleteContext(
    profile: profile ?? this.profile,
    week: week ?? this.week,
    race: race ?? this.race,
    budget: budget ?? this.budget,
    weather: weather ?? this.weather,
    holidays: holidays ?? this.holidays,
    loggedToday: loggedToday ?? this.loggedToday,
    plan: plan ?? this.plan,
    memories: memories ?? this.memories,
  );
}

class AthleteProfileContext extends WireRecord {
  const AthleteProfileContext({
    this.firstName,
    this.diet,
    this.allergies = const [],
    this.gutTraining,
  });

  final String? firstName;
  final String? diet;
  final List<String> allergies;
  final String? gutTraining;

  factory AthleteProfileContext.fromJson(Map<String, dynamic> json) =>
      AthleteProfileContext(
        firstName: readString(json, 'firstName'),
        diet: readString(json, 'diet'),
        allergies: readStringList(json, 'allergies'),
        gutTraining: readString(json, 'gutTraining'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'diet': diet,
    'allergies': allergies,
    'gutTraining': gutTraining,
  };
}

class AthleteWorkoutContext extends WireRecord {
  const AthleteWorkoutContext({
    required this.date,
    required this.title,
    required this.type,
    this.minutes,
    this.intensity,
  });

  final String date;
  final String title;
  final String type;
  final int? minutes;
  final String? intensity;

  factory AthleteWorkoutContext.fromJson(Map<String, dynamic> json) =>
      AthleteWorkoutContext(
        date: readString(json, 'date') ?? '',
        title: readString(json, 'title') ?? '',
        type: readString(json, 'type') ?? '',
        minutes: readInt(json, 'minutes'),
        intensity: readString(json, 'intensity'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'date': date,
    'title': title,
    'type': type,
    'minutes': minutes,
    'intensity': intensity,
  };
}

class AthleteWeekContext extends WireRecord {
  const AthleteWeekContext({
    required this.start,
    required this.character,
    this.anchor,
    required this.loadScore,
    this.workouts = const [],
  });

  /// `YYYY-MM-DD` (Monday).
  final String start;

  /// e.g. "rest week", "build".
  final String character;
  final String? anchor;
  final double loadScore;
  final List<AthleteWorkoutContext> workouts;

  factory AthleteWeekContext.fromJson(Map<String, dynamic> json) =>
      AthleteWeekContext(
        start: readString(json, 'start') ?? '',
        character: readString(json, 'character') ?? '',
        anchor: readString(json, 'anchor'),
        loadScore: readDouble(json, 'loadScore') ?? 0,
        workouts: readRecordList(
          json,
          'workouts',
          AthleteWorkoutContext.fromJson,
        ),
      );

  @override
  Map<String, dynamic> toJson() => {
    'start': start,
    'character': character,
    'anchor': anchor,
    'loadScore': loadScore,
    'workouts': workouts.map((w) => w.toJson()).toList(),
  };
}

class AthleteRaceContext extends WireRecord {
  const AthleteRaceContext({
    required this.name,
    required this.date,
    required this.daysOut,
    this.location,
  });

  final String name;
  final String date;
  final int daysOut;
  final String? location;

  factory AthleteRaceContext.fromJson(Map<String, dynamic> json) =>
      AthleteRaceContext(
        name: readString(json, 'name') ?? '',
        date: readString(json, 'date') ?? '',
        daysOut: readInt(json, 'daysOut') ?? 0,
        location: readString(json, 'location'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date,
    'daysOut': daysOut,
    'location': location,
  };
}

/// Straight from `daily_macro_targets`; never recomputed.
class AthleteBudgetContext extends WireRecord {
  const AthleteBudgetContext({
    this.today,
    this.week = const [],
    this.raceWeekCarbsG,
  });

  final DayTarget? today;
  final List<DayTarget> week;
  final int? raceWeekCarbsG;

  factory AthleteBudgetContext.fromJson(Map<String, dynamic> json) =>
      AthleteBudgetContext(
        today: switch (asJsonMap(json['today'])) {
          final map? => DayTarget.fromJson(map),
          null => null,
        },
        week: readRecordList(json, 'week', DayTarget.fromJson),
        raceWeekCarbsG: readInt(json, 'raceWeekCarbsG'),
      );

  @override
  Map<String, dynamic> toJson() => {
    'today': today?.toJson(),
    'week': week.map((t) => t.toJson()).toList(),
    'raceWeekCarbsG': raceWeekCarbsG,
  };
}

class AthleteWeatherContext extends WireRecord {
  const AthleteWeatherContext({this.today, this.raceDay});

  final String? today;
  final String? raceDay;

  factory AthleteWeatherContext.fromJson(Map<String, dynamic> json) =>
      AthleteWeatherContext(
        today: readString(json, 'today'),
        raceDay: readString(json, 'raceDay'),
      );

  @override
  Map<String, dynamic> toJson() => {'today': today, 'raceDay': raceDay};
}

/// A US holiday in the next two weeks.
class AthleteHoliday extends WireRecord {
  const AthleteHoliday({
    required this.date,
    required this.name,
    required this.daysOut,
  });

  final String date;
  final String name;
  final int daysOut;

  factory AthleteHoliday.fromJson(Map<String, dynamic> json) => AthleteHoliday(
    date: readString(json, 'date') ?? '',
    name: readString(json, 'name') ?? '',
    daysOut: readInt(json, 'daysOut') ?? 0,
  );

  @override
  Map<String, dynamic> toJson() => {
    'date': date,
    'name': name,
    'daysOut': daysOut,
  };
}

class AthleteLoggedToday extends WireRecord {
  const AthleteLoggedToday({required this.count, required this.carbsG});

  final int count;
  final double carbsG;

  factory AthleteLoggedToday.fromJson(Map<String, dynamic> json) =>
      AthleteLoggedToday(
        count: readInt(json, 'count') ?? 0,
        carbsG: readDouble(json, 'carbsG') ?? 0,
      );

  @override
  Map<String, dynamic> toJson() => {'count': count, 'carbsG': carbsG};
}

class AthletePlanContext extends WireRecord {
  const AthletePlanContext({
    required this.exists,
    this.status,
    this.mealsLeft,
    required this.batchCooking,
  });

  final bool exists;

  /// Raw plan status string (`draft` / `confirmed`), null when no plan.
  final String? status;
  final int? mealsLeft;
  final bool batchCooking;

  factory AthletePlanContext.fromJson(Map<String, dynamic> json) =>
      AthletePlanContext(
        exists: readBool(json, 'exists') ?? false,
        status: readString(json, 'status'),
        mealsLeft: readInt(json, 'mealsLeft'),
        batchCooking: readBool(json, 'batchCooking') ?? false,
      );

  @override
  Map<String, dynamic> toJson() => {
    'exists': exists,
    'status': status,
    'mealsLeft': mealsLeft,
    'batchCooking': batchCooking,
  };
}
