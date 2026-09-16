import 'directions_origin.dart';
import 'meal_photo.dart';
import 'meal_ref.dart';
import 'wire_record.dart';

/// What the meal detail page and cooking mode need — `MealDetail` in
/// `contracts.ts`; built by the `get_meal` action for a library id or a
/// saved uuid.
class MealDetail extends WireRecord {
  const MealDetail({
    required this.meal,
    this.ingredients = const [],
    this.methodSteps = const [],
    required this.directions,
    this.photo,
    this.sourceUrl,
    this.source = '',
    this.swaps = const [],
    this.prep,
    required this.servings,
    this.notes,
    this.vote = 0,
  });

  final MealRef meal;

  /// Library `ingredients_json` / saved-meal items.
  final List<MealIngredient> ingredients;

  /// `meal_library.method_steps` (a saved meal inherits its linked recipe's).
  final List<String> methodSteps;

  /// Provenance of [methodSteps].
  final MealDirections directions;

  /// The Meal's Dish photo, or null when the recipe screen starts at the
  /// title with no picture above it (ADR 0003).
  final MealPhoto? photo;

  /// "See the original recipe".
  final String? sourceUrl;

  /// Full attribution line (library) — `''` for saved.
  final String source;

  /// "water→milk (+10g protein)" strings, one per swap.
  final List<String> swaps;
  final String? prep;
  final int servings;

  /// Saved meals only — the athlete's own directions.
  final String? notes;

  /// -1 down, 1 up, 0 none.
  final int vote;

  bool get hasSteps => methodSteps.isNotEmpty;

  factory MealDetail.fromJson(Map<String, dynamic> json) => MealDetail(
    meal: MealRef.fromJson(requireJsonMap(json, 'meal')),
    ingredients: readRecordList(json, 'ingredients', MealIngredient.fromJson),
    methodSteps: readStringList(json, 'methodSteps'),
    directions: MealDirections.fromJson(
      asJsonMap(json['directions']) ?? const <String, dynamic>{},
    ),
    photo: MealPhoto.fromJsonOrNull(asJsonMap(json['photo'])),
    sourceUrl: readString(json, 'sourceUrl'),
    source: readString(json, 'source') ?? '',
    swaps: readStringList(json, 'swaps'),
    prep: readString(json, 'prep'),
    servings: readInt(json, 'servings') ?? 1,
    notes: readString(json, 'notes'),
    vote: readInt(json, 'vote') ?? 0,
  );

  @override
  Map<String, dynamic> toJson() => {
    'meal': meal.toJson(),
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'methodSteps': methodSteps,
    'directions': directions.toJson(),
    'photo': photo?.toJson(),
    'sourceUrl': sourceUrl,
    'source': source,
    'swaps': swaps,
    'prep': prep,
    'servings': servings,
    'notes': notes,
    'vote': vote,
  };

  MealDetail copyWith({
    MealRef? meal,
    List<MealIngredient>? ingredients,
    List<String>? methodSteps,
    MealDirections? directions,
    MealPhoto? photo,
    String? sourceUrl,
    String? source,
    List<String>? swaps,
    String? prep,
    int? servings,
    String? notes,
    int? vote,
  }) => MealDetail(
    meal: meal ?? this.meal,
    ingredients: ingredients ?? this.ingredients,
    methodSteps: methodSteps ?? this.methodSteps,
    directions: directions ?? this.directions,
    photo: photo ?? this.photo,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    source: source ?? this.source,
    swaps: swaps ?? this.swaps,
    prep: prep ?? this.prep,
    servings: servings ?? this.servings,
    notes: notes ?? this.notes,
    vote: vote ?? this.vote,
  );
}

/// `MealIngredient {name, qty, role?}`.
class MealIngredient extends WireRecord {
  const MealIngredient({required this.name, required this.qty, this.role});

  final String name;
  final String qty;

  /// `?: string | null` in TS — emitted only when set.
  final String? role;

  factory MealIngredient.fromJson(Map<String, dynamic> json) => MealIngredient(
    name: readString(json, 'name') ?? '',
    qty: readString(json, 'qty') ?? '',
    role: readString(json, 'role'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    if (role != null) 'role': role,
  };

  MealIngredient copyWith({String? name, String? qty, String? role}) =>
      MealIngredient(
        name: name ?? this.name,
        qty: qty ?? this.qty,
        role: role ?? this.role,
      );
}

/// `MealDetail.directions` — provenance of the method steps.
class MealDirections extends WireRecord {
  const MealDirections({
    this.origin,
    this.sourceUrl,
    this.sourceName,
    this.verbatim = false,
  });

  static const none = MealDirections();

  final DirectionsOrigin? origin;
  final String? sourceUrl;
  final String? sourceName;

  /// Steps are reproduced as published by [sourceName].
  final bool verbatim;

  factory MealDirections.fromJson(Map<String, dynamic> json) => MealDirections(
    origin: DirectionsOrigin.fromWire(readString(json, 'origin')),
    sourceUrl: readString(json, 'sourceUrl'),
    sourceName: readString(json, 'sourceName'),
    verbatim: readBool(json, 'verbatim') ?? false,
  );

  @override
  Map<String, dynamic> toJson() => {
    'origin': origin?.wire,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
    'verbatim': verbatim,
  };

  MealDirections copyWith({
    DirectionsOrigin? origin,
    String? sourceUrl,
    String? sourceName,
    bool? verbatim,
  }) => MealDirections(
    origin: origin ?? this.origin,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sourceName: sourceName ?? this.sourceName,
    verbatim: verbatim ?? this.verbatim,
  );
}
