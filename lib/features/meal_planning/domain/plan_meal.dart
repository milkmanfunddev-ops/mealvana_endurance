import 'cooking_session.dart';
import 'meal_icon.dart';
import 'meal_source.dart';
import 'meal_type.dart';
import 'wire_record.dart';

/// A `plan_meals` row — `PlanMeal` in `contracts.ts`.
class PlanMeal extends WireRecord {
  const PlanMeal({
    required this.id,
    required this.planId,
    required this.source,
    this.libraryMealId,
    this.savedMealId,
    required this.name,
    required this.mealType,
    this.session,
    required this.servings,
    required this.servingsLeft,
    this.kcal,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.swapsApplied = const [],
    this.comments = const [],
    this.position = 0,
    this.icon,
  });

  final String id;
  final String planId;
  final MealSource source;
  final String? libraryMealId;
  final String? savedMealId;
  final String name;
  final MealType mealType;

  /// `null` = no batch-cooking session.
  final CookingSession? session;
  final int servings;
  final int servingsLeft;
  final int? kcal;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final List<SwapApplied> swapsApplied;
  final List<PlanComment> comments;
  final int position;

  /// Icon key copied from the source meal at add/swap time.
  final MealIcon? icon;

  factory PlanMeal.fromJson(Map<String, dynamic> json) {
    return PlanMeal(
      id: requireString(json, 'id'),
      planId: requireString(json, 'planId'),
      source: MealSource.requireWire(readString(json, 'source')),
      libraryMealId: readString(json, 'libraryMealId'),
      savedMealId: readString(json, 'savedMealId'),
      name: requireString(json, 'name'),
      mealType: MealType.requireWire(readString(json, 'mealType')),
      session: CookingSession.fromWire(readString(json, 'session')),
      servings: readInt(json, 'servings') ?? 0,
      servingsLeft: readInt(json, 'servingsLeft') ?? 0,
      kcal: readInt(json, 'kcal'),
      carbsG: readDouble(json, 'carbsG'),
      proteinG: readDouble(json, 'proteinG'),
      fatG: readDouble(json, 'fatG'),
      swapsApplied: readRecordList(json, 'swapsApplied', SwapApplied.fromJson),
      comments: readRecordList(json, 'comments', PlanComment.fromJson),
      position: readInt(json, 'position') ?? 0,
      icon: MealIcon.fromWire(readString(json, 'icon')),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'planId': planId,
    'source': source.wire,
    'libraryMealId': libraryMealId,
    'savedMealId': savedMealId,
    'name': name,
    'mealType': mealType.wire,
    'session': session?.wire,
    'servings': servings,
    'servingsLeft': servingsLeft,
    'kcal': kcal,
    'carbsG': carbsG,
    'proteinG': proteinG,
    'fatG': fatG,
    'swapsApplied': swapsApplied.map((s) => s.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
    'position': position,
    if (icon != null) 'icon': icon!.wire,
  };

  PlanMeal copyWith({
    String? id,
    String? planId,
    MealSource? source,
    String? libraryMealId,
    String? savedMealId,
    String? name,
    MealType? mealType,
    CookingSession? session,

    /// When true, sets [session] to `null` regardless of the [session]
    /// argument (`session ?? this.session` cannot express "clear it").
    bool clearSession = false,
    int? servings,
    int? servingsLeft,
    int? kcal,
    double? carbsG,
    double? proteinG,
    double? fatG,
    List<SwapApplied>? swapsApplied,
    List<PlanComment>? comments,
    int? position,
    MealIcon? icon,
  }) {
    return PlanMeal(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      source: source ?? this.source,
      libraryMealId: libraryMealId ?? this.libraryMealId,
      savedMealId: savedMealId ?? this.savedMealId,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      session: clearSession ? null : (session ?? this.session),
      servings: servings ?? this.servings,
      servingsLeft: servingsLeft ?? this.servingsLeft,
      kcal: kcal ?? this.kcal,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      swapsApplied: swapsApplied ?? this.swapsApplied,
      comments: comments ?? this.comments,
      position: position ?? this.position,
      icon: icon ?? this.icon,
    );
  }
}

/// One entry of `PlanMeal.swapsApplied` — `{from, to, effect?}`.
class SwapApplied extends WireRecord {
  const SwapApplied({required this.from, required this.to, this.effect});

  final String from;
  final String to;

  /// e.g. "+10g protein".
  final String? effect;

  factory SwapApplied.fromJson(Map<String, dynamic> json) => SwapApplied(
    from: requireString(json, 'from'),
    to: requireString(json, 'to'),
    effect: readString(json, 'effect'),
  );

  @override
  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    if (effect != null) 'effect': effect,
  };

  SwapApplied copyWith({String? from, String? to, String? effect}) =>
      SwapApplied(
        from: from ?? this.from,
        to: to ?? this.to,
        effect: effect ?? this.effect,
      );
}

/// Author of a [PlanComment].
enum PlanCommentRole {
  user('user'),
  vana('vana');

  const PlanCommentRole(this.wire);

  final String wire;

  static PlanCommentRole? fromWire(String? value) {
    if (value == null) return null;
    for (final v in PlanCommentRole.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}

/// One entry of `PlanMeal.comments` — `{role, text, at}`.
class PlanComment extends WireRecord {
  const PlanComment({required this.role, required this.text, required this.at});

  final PlanCommentRole role;
  final String text;

  /// ISO timestamp as sent.
  final String at;

  DateTime? get atDateTime => DateTime.tryParse(at);

  factory PlanComment.fromJson(Map<String, dynamic> json) => PlanComment(
    role:
        PlanCommentRole.fromWire(readString(json, 'role')) ??
        (throw FormatException('Unknown comment role "${json['role']}"')),
    text: readString(json, 'text') ?? '',
    at: readString(json, 'at') ?? '',
  );

  @override
  Map<String, dynamic> toJson() => {'role': role.wire, 'text': text, 'at': at};

  PlanComment copyWith({PlanCommentRole? role, String? text, String? at}) =>
      PlanComment(
        role: role ?? this.role,
        text: text ?? this.text,
        at: at ?? this.at,
      );
}
