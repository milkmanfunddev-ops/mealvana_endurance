import 'meal_context.dart';
import 'meal_icon.dart';
import 'meal_source.dart';
import 'meal_type.dart';
import 'wire_record.dart';

/// One `search_meals()` row — `MealRef` in `contracts.ts`.
///
/// Optional fields (`kind pattern frequency icon myVote`) are emitted only
/// when set, matching the TS `?:` members; nullable required fields
/// (`prepMinutes kcal … swaps libraryMealId`) are always emitted.
class MealRef extends WireRecord {
  const MealRef({
    required this.source,
    required this.id,
    required this.name,
    required this.mealType,
    this.contexts = const [],
    this.batch = false,
    this.prepMinutes,
    this.kcal,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.allergens = const [],
    this.dietsOk = const [],
    this.swaps,
    this.why = '',
    this.attribution = '',
    this.attributionShort = '',
    this.ingredients = '',
    this.libraryMealId,
    this.score = 0,
    this.kind,
    this.pattern,
    this.frequency,
    this.icon,
    this.myVote,
  });

  final MealSource source;

  /// `'D-048'` for library meals, the `saved_meals` uuid for saved ones.
  final String id;
  final String name;
  final MealType mealType;
  final List<MealContext> contexts;
  final bool batch;
  final int? prepMinutes;
  final int? kcal;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final List<String> allergens;
  final List<String> dietsOk;

  /// Free-text swap suggestions from the library row.
  final String? swaps;

  /// One honest line — the card's subtitle.
  final String why;

  /// Full source string (detail sheet only).
  final String attribution;

  /// ≤40 chars: first named person/source — what cards and the model see.
  final String attributionShort;

  /// Comma-joined ingredient line.
  final String ingredients;

  /// For saved meals matched to the library.
  final String? libraryMealId;
  final double score;

  /// Assembly vs recipe. Absent on some rows (e.g. staples built from logs).
  final MealKind? kind;

  /// Assemblies: "protein + starch + veg".
  final String? pattern;

  /// staple / common / occasional.
  final String? frequency;

  /// Stored icon key. `null` when the row predates the column or the stored
  /// key is not a known [MealIcon] — resolve through `MealIconClassifier`.
  final MealIcon? icon;

  /// This user's thumb: -1 down, 1 up, 0 none.
  final int? myVote;

  factory MealRef.fromJson(Map<String, dynamic> json) {
    return MealRef(
      source: MealSource.requireWire(readString(json, 'source')),
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      mealType: MealType.requireWire(readString(json, 'mealType')),
      contexts: MealContext.listFromWire(readStringList(json, 'contexts')),
      batch: readBool(json, 'batch') ?? false,
      prepMinutes: readInt(json, 'prepMinutes'),
      kcal: readInt(json, 'kcal'),
      carbsG: readDouble(json, 'carbsG'),
      proteinG: readDouble(json, 'proteinG'),
      fatG: readDouble(json, 'fatG'),
      allergens: readStringList(json, 'allergens'),
      dietsOk: readStringList(json, 'dietsOk'),
      swaps: readString(json, 'swaps'),
      why: readString(json, 'why') ?? '',
      attribution: readString(json, 'attribution') ?? '',
      attributionShort: readString(json, 'attributionShort') ?? '',
      ingredients: readString(json, 'ingredients') ?? '',
      libraryMealId: readString(json, 'libraryMealId'),
      score: readDouble(json, 'score') ?? 0,
      kind: MealKind.fromWire(readString(json, 'kind')),
      pattern: readString(json, 'pattern'),
      frequency: readString(json, 'frequency'),
      icon: MealIcon.fromWire(readString(json, 'icon')),
      myVote: readInt(json, 'myVote'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'source': source.wire,
    'id': id,
    'name': name,
    'mealType': mealType.wire,
    'contexts': contexts.map((c) => c.wire).toList(),
    'batch': batch,
    'prepMinutes': prepMinutes,
    'kcal': kcal,
    'carbsG': carbsG,
    'proteinG': proteinG,
    'fatG': fatG,
    'allergens': allergens,
    'dietsOk': dietsOk,
    'swaps': swaps,
    'why': why,
    'attribution': attribution,
    'attributionShort': attributionShort,
    'ingredients': ingredients,
    'libraryMealId': libraryMealId,
    'score': score,
    if (kind != null) 'kind': kind!.wire,
    if (pattern != null) 'pattern': pattern,
    if (frequency != null) 'frequency': frequency,
    if (icon != null) 'icon': icon!.wire,
    if (myVote != null) 'myVote': myVote,
  };

  MealRef copyWith({
    MealSource? source,
    String? id,
    String? name,
    MealType? mealType,
    List<MealContext>? contexts,
    bool? batch,
    int? prepMinutes,
    int? kcal,
    double? carbsG,
    double? proteinG,
    double? fatG,
    List<String>? allergens,
    List<String>? dietsOk,
    String? swaps,
    String? why,
    String? attribution,
    String? attributionShort,
    String? ingredients,
    String? libraryMealId,
    double? score,
    MealKind? kind,
    String? pattern,
    String? frequency,
    MealIcon? icon,
    int? myVote,
  }) {
    return MealRef(
      source: source ?? this.source,
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      contexts: contexts ?? this.contexts,
      batch: batch ?? this.batch,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      kcal: kcal ?? this.kcal,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      allergens: allergens ?? this.allergens,
      dietsOk: dietsOk ?? this.dietsOk,
      swaps: swaps ?? this.swaps,
      why: why ?? this.why,
      attribution: attribution ?? this.attribution,
      attributionShort: attributionShort ?? this.attributionShort,
      ingredients: ingredients ?? this.ingredients,
      libraryMealId: libraryMealId ?? this.libraryMealId,
      score: score ?? this.score,
      kind: kind ?? this.kind,
      pattern: pattern ?? this.pattern,
      frequency: frequency ?? this.frequency,
      icon: icon ?? this.icon,
      myVote: myVote ?? this.myVote,
    );
  }
}

/// A `staples` part entry — `MealRef & { timesLogged, ticked }` (flattened
/// on the wire).
class StapleMeal extends WireRecord {
  const StapleMeal({
    required this.meal,
    required this.timesLogged,
    required this.ticked,
  });

  final MealRef meal;
  final int timesLogged;
  final bool ticked;

  factory StapleMeal.fromJson(Map<String, dynamic> json) => StapleMeal(
    meal: MealRef.fromJson(json),
    timesLogged: readInt(json, 'timesLogged') ?? 0,
    ticked: readBool(json, 'ticked') ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {
    ...meal.toJson(),
    'timesLogged': timesLogged,
    'ticked': ticked,
  };

  StapleMeal copyWith({MealRef? meal, int? timesLogged, bool? ticked}) =>
      StapleMeal(
        meal: meal ?? this.meal,
        timesLogged: timesLogged ?? this.timesLogged,
        ticked: ticked ?? this.ticked,
      );
}

/// A `recent_meals` action row — `MealRef & { lastUsedAt }` (flattened).
///
/// `lastUsedAt` is an ISO timestamp (or `''` when the source row had no
/// usable time — see prototype `recentMeals`).
class RecentMeal extends WireRecord {
  const RecentMeal({required this.meal, required this.lastUsedAt});

  final MealRef meal;
  final String lastUsedAt;

  DateTime? get lastUsedAtDateTime => DateTime.tryParse(lastUsedAt);

  factory RecentMeal.fromJson(Map<String, dynamic> json) => RecentMeal(
    meal: MealRef.fromJson(json),
    lastUsedAt: readString(json, 'lastUsedAt') ?? '',
  );

  @override
  Map<String, dynamic> toJson() => {...meal.toJson(), 'lastUsedAt': lastUsedAt};

  RecentMeal copyWith({MealRef? meal, String? lastUsedAt}) => RecentMeal(
    meal: meal ?? this.meal,
    lastUsedAt: lastUsedAt ?? this.lastUsedAt,
  );
}
