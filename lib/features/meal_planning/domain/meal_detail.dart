import 'directions_origin.dart';
import 'meal_image.dart';
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
    this.image,
    this.sourceUrl,
    this.source = '',
    this.swaps = const [],
    this.prep,
    required this.servings,
    this.notes,
    this.vote = 0,
    this.imageMode = MealImageMode.none,
    this.imageTiles = const <MealImageTile>[],
  });

  final MealRef meal;

  /// Library `ingredients_json` / saved-meal items.
  final List<MealIngredient> ingredients;

  /// `meal_library.method_steps` (a saved meal inherits its linked recipe's).
  final List<String> methodSteps;

  /// Provenance of [methodSteps].
  final MealDirections directions;
  final MealImage? image;

  /// Which rung of the image fallback ladder this meal reached — see
  /// `docs/meal-images/README.md` and the Meal Image Mosaic component spec.
  final MealImageMode imageMode;

  /// Ingredient tiles used when no real dish photo exists; empty otherwise.
  final List<MealImageTile> imageTiles;

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
    image: switch (asJsonMap(json['image'])) {
      final map? => MealImage.fromJson(map),
      null => null,
    },
    sourceUrl: readString(json, 'sourceUrl'),
    source: readString(json, 'source') ?? '',
    swaps: readStringList(json, 'swaps'),
    prep: readString(json, 'prep'),
    servings: readInt(json, 'servings') ?? 1,
    notes: readString(json, 'notes'),
    vote: readInt(json, 'vote') ?? 0,
    imageMode: MealImageMode.fromWire(readString(json, 'imageMode')),
    imageTiles: readRecordList(json, 'imageTiles', MealImageTile.fromJson),
  );

  @override
  Map<String, dynamic> toJson() => {
    'meal': meal.toJson(),
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'methodSteps': methodSteps,
    'directions': directions.toJson(),
    'image': image?.toJson(),
    'sourceUrl': sourceUrl,
    'source': source,
    'swaps': swaps,
    'prep': prep,
    'servings': servings,
    'notes': notes,
    'vote': vote,
    'imageMode': imageMode.name,
    'imageTiles': imageTiles.map((t) => t.toJson()).toList(),
  };

  MealDetail copyWith({
    MealRef? meal,
    List<MealIngredient>? ingredients,
    List<String>? methodSteps,
    MealDirections? directions,
    MealImage? image,
    String? sourceUrl,
    String? source,
    List<String>? swaps,
    String? prep,
    int? servings,
    String? notes,
    int? vote,
    MealImageMode? imageMode,
    List<MealImageTile>? imageTiles,
  }) => MealDetail(
    meal: meal ?? this.meal,
    ingredients: ingredients ?? this.ingredients,
    methodSteps: methodSteps ?? this.methodSteps,
    directions: directions ?? this.directions,
    image: image ?? this.image,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    source: source ?? this.source,
    swaps: swaps ?? this.swaps,
    prep: prep ?? this.prep,
    servings: servings ?? this.servings,
    notes: notes ?? this.notes,
    vote: vote ?? this.vote,
    imageMode: imageMode ?? this.imageMode,
    imageTiles: imageTiles ?? this.imageTiles,
  );

  /// The tiles to render, honouring the ladder: a real dish photo outranks
  /// every ingredient tile.
  List<MealImageTile> get displayTiles => switch (imageMode) {
    MealImageMode.dish || MealImageMode.tile => [
      if (image != null)
        MealImageTile(
          url: image!.url,
          license: image!.license,
          creator: image!.creator,
          sourceUrl: image!.sourceUrl,
        )
      else
        ...imageTiles.take(1),
    ],
    MealImageMode.mosaic => imageTiles,
    MealImageMode.none => const <MealImageTile>[],
  };
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
