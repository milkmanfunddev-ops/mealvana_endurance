import 'food_item_data.dart';
import 'macro_shortfall.dart';
import 'pre_workout_feeding_labels.dart';
import 'time_slot_assignment.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Sub-phase within the "before" section (meal, snack, top_up)
/// Used when the plan is generated via template-based v2 system.
class BeforeSubPhase {
  const BeforeSubPhase({
    required this.subPhaseType,
    required this.foodItems,
    this.carbsTarget,
    this.proteinTarget,
    this.fatTarget,
    this.sodiumTarget,
    this.fluidsTarget,
    this.templateId,
    this.templateName,
    this.shortfalls = const <MacroShortfall>[],
    this.pinDecision,
  });

  final String subPhaseType; // 'meal', 'snack', 'top_up'
  final List<FoodItemData> foodItems;
  final double? carbsTarget;
  final double? proteinTarget;
  final double? fatTarget;
  final double? sodiumTarget;
  final double? fluidsTarget;
  final String? templateId;
  final String? templateName;

  /// Macros the algorithm could not satisfy due to user preference filtering
  /// (dislikes, allergens, diet exclusions). Empty list means clean fit.
  /// Issue #14 / #15.
  final List<MacroShortfall> shortfalls;

  /// Pin honoring telemetry for this sub-phase. Populated only when pins
  /// were supplied to the algorithm. Used by the activity-detail pin banner
  /// (Formula Kit PR 2 substep 9).
  final PinDecision? pinDecision;

  /// Display title for this sub-phase, sport-aware when [sport] is known
  /// ("Pre-Run Meal" / "Pre-Ride Meal"), generic ("Pre-Workout Meal")
  /// otherwise. See [preWorkoutFeedingTitle].
  String displayTitleFor(ActivityType? sport) =>
      preWorkoutFeedingTitle(subPhaseType, sport: sport);

  /// Sport-agnostic display title for this sub-phase.
  String get displayTitle => displayTitleFor(null);

  /// Summary of this sub-phase for collapsed display.
  ///
  /// Prefers the curated template's own name ("Smoothie", "Oatmeal + Raisins")
  /// so a multi-ingredient recommendation reads as one item; falls back to
  /// joining the ingredient names when no curated name exists
  /// (bug 3abe3fdb754c8153: the getter used to gate templateName behind an
  /// empty-foodItems condition that never occurs, so the name was never shown).
  String get templateSummary {
    final name = templateName;
    if (name != null && name.isNotEmpty) return name;
    if (foodItems.isEmpty) return '';
    return foodItems
        .map((f) => _simplifyName(f.displayName ?? f.name))
        .join(' + ');
  }

  static String _simplifyName(String raw) {
    return raw.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  factory BeforeSubPhase.fromJson(Map<String, dynamic> json) {
    return BeforeSubPhase(
      subPhaseType:
          json['sub_phase_type'] as String? ?? json['subPhaseType'] as String,
      foodItems:
          (json['foods'] as List<dynamic>? ??
                  json['foodItems'] as List<dynamic>? ??
                  [])
              .map((item) {
                if (item is Map<String, dynamic>) {
                  // Check if it's edge function format (has food_id) or standard format
                  if (item.containsKey('food_id')) {
                    return FoodItemData.fromEdgeFunctionJson(item);
                  }
                  return FoodItemData.fromJson(item);
                }
                return FoodItemData(id: '', name: 'Unknown', quantity: '0');
              })
              .toList(),
      carbsTarget:
          (json['targets'] is Map
              ? (json['targets']['carbs_g'] as num?)?.toDouble()
              : null) ??
          (json['carbsTarget'] as num?)?.toDouble(),
      proteinTarget:
          (json['targets'] is Map
              ? (json['targets']['protein_g'] as num?)?.toDouble()
              : null) ??
          (json['proteinTarget'] as num?)?.toDouble(),
      fatTarget:
          (json['targets'] is Map
              ? (json['targets']['fat_g'] as num?)?.toDouble()
              : null) ??
          (json['fatTarget'] as num?)?.toDouble(),
      sodiumTarget:
          (json['targets'] is Map
              ? (json['targets']['sodium_mg'] as num?)?.toDouble()
              : null) ??
          (json['sodiumTarget'] as num?)?.toDouble(),
      fluidsTarget:
          (json['targets'] is Map
              ? (json['targets']['water_ml'] as num?)?.toDouble()
              : null) ??
          (json['fluidsTarget'] as num?)?.toDouble(),
      templateId:
          json['template_id'] as String? ?? json['templateId'] as String?,
      templateName:
          json['template_name'] as String? ?? json['templateName'] as String?,
      shortfalls: ((json['shortfalls'] as List<dynamic>?) ?? const [])
          .map((e) => MacroShortfall.fromJson(e as Map<String, dynamic>))
          .toList(),
      pinDecision: _parsePinDecision(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subPhaseType': subPhaseType,
      'foodItems': foodItems.map((item) => item.toJson()).toList(),
      'carbsTarget': carbsTarget,
      'proteinTarget': proteinTarget,
      'fatTarget': fatTarget,
      'sodiumTarget': sodiumTarget,
      'fluidsTarget': fluidsTarget,
      'templateId': templateId,
      'templateName': templateName,
      if (shortfalls.isNotEmpty)
        'shortfalls': shortfalls.map((s) => s.toJson()).toList(),
      if (pinDecision != null) 'pinDecision': pinDecision!.toJson(),
    };
  }

  BeforeSubPhase copyWith({
    String? subPhaseType,
    List<FoodItemData>? foodItems,
    double? carbsTarget,
    double? proteinTarget,
    double? fatTarget,
    double? sodiumTarget,
    double? fluidsTarget,
    String? templateId,
    String? templateName,
    List<MacroShortfall>? shortfalls,
    PinDecision? pinDecision,
  }) {
    return BeforeSubPhase(
      subPhaseType: subPhaseType ?? this.subPhaseType,
      foodItems: foodItems ?? this.foodItems,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      sodiumTarget: sodiumTarget ?? this.sodiumTarget,
      fluidsTarget: fluidsTarget ?? this.fluidsTarget,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      shortfalls: shortfalls ?? this.shortfalls,
      pinDecision: pinDecision ?? this.pinDecision,
    );
  }

  /// Parse pin_decision from either edge fn (`pin_decision`, snake_case) or
  /// persisted (`pinDecision`, camelCase) JSON shape. Returns null when
  /// absent — the algorithm omits the field entirely when pins were not
  /// supplied to the call.
  static PinDecision? _parsePinDecision(Map<String, dynamic> json) {
    final raw = json['pin_decision'] ?? json['pinDecision'];
    if (raw is! Map<String, dynamic>) return null;
    return PinDecision.fromJson(raw);
  }

  @override
  String toString() =>
      'BeforeSubPhase($subPhaseType, items: ${foodItems.length})';
}

/// Section within a nutrition plan (Before/During/After Run)
class PlanSection {
  const PlanSection({
    required this.id,
    required this.title,
    required this.foodItems,
    this.subtitle,
    this.timing,
    this.proteinTarget,
    this.fatTarget,
    this.carbsTarget,
    this.sodiumTarget,
    this.fluidsTarget,
    this.carbsLowTarget,
    this.carbsHighTarget,
    this.proteinLowTarget,
    this.proteinHighTarget,
    this.sodiumLowTarget,
    this.sodiumHighTarget,
    this.fluidsLowTarget,
    this.fluidsHighTarget,
    this.subPhases,
    this.byHourData,
    this.pinDecision,
    this.shortfalls = const <MacroShortfall>[],
  });

  final String id;
  final String title; // "Before Run", "During Run", "After Run"
  final String? subtitle; // "30-60 min pre-run"
  final String? timing;
  final List<FoodItemData> foodItems;

  // Macro targets for this section (nullable with defaults)
  final double? proteinTarget; // grams
  final double? fatTarget; // grams
  final double? carbsTarget; // grams
  final double? sodiumTarget; // milligrams
  final double? fluidsTarget; // milliliters
  final double? carbsLowTarget; // grams
  final double? carbsHighTarget; // grams
  final double? proteinLowTarget; // grams
  final double? proteinHighTarget; // grams
  final double? sodiumLowTarget; // milligrams
  final double? sodiumHighTarget; // milligrams
  final double? fluidsLowTarget; // milliliters
  final double? fluidsHighTarget; // milliliters

  /// Nested sub-phases for template-based "before" sections.
  /// When present, foodItems list is empty (foods live in sub-phases instead).
  final List<BeforeSubPhase>? subPhases;

  /// By-hour time slot assignments for during-activity sections.
  /// Lazily initialized on first "By Hour" toggle for qualifying sections.
  final ByHourData? byHourData;

  /// Pin honoring telemetry for this section. Populated only when pins were
  /// supplied to the algorithm; today only the During section ever carries
  /// one at the section level (Before pins live on each [BeforeSubPhase]).
  /// Used by the activity-detail pin banner (Formula Kit PR 2 substep 9).
  final PinDecision? pinDecision;

  /// Macros the solver could not satisfy for this section. Mirrors
  /// [BeforeSubPhase.shortfalls] (Before carries them per sub-phase); today
  /// only the During section ever carries them at the section level, from
  /// `plan.during.shortfalls` in the V3 response. Empty list means clean
  /// fit. Bug 3a3e3fdb: these were previously discarded, so during-phase
  /// plans silently missed carb targets.
  final List<MacroShortfall> shortfalls;

  /// Whether this section uses the template-based sub-phase layout
  bool get hasSubPhases => subPhases != null && subPhases!.isNotEmpty;

  /// Whether this section supports the by-hour view (>= 60 min duration)
  bool get supportsByHour =>
      byHourData != null && byHourData!.durationMinutes >= 60;

  /// Create PlanSection from JSON
  factory PlanSection.fromJson(Map<String, dynamic> json) {
    // Parse sub-phases if present
    List<BeforeSubPhase>? subPhases;
    if (json['subPhases'] is List) {
      subPhases = (json['subPhases'] as List<dynamic>)
          .map((sp) => BeforeSubPhase.fromJson(sp as Map<String, dynamic>))
          .toList();
    }

    // Parse byHourData if present
    ByHourData? byHourData;
    if (json['byHourData'] is Map<String, dynamic>) {
      byHourData = ByHourData.fromJson(
        json['byHourData'] as Map<String, dynamic>,
      );
    }

    return PlanSection(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      timing: json['timing'] as String?,
      foodItems:
          (json['foodItems'] as List<dynamic>?)
              ?.map((item) => FoodItemData.fromJson(item))
              .toList() ??
          [],
      proteinTarget: (json['proteinTarget'] as num?)?.toDouble(),
      fatTarget: (json['fatTarget'] as num?)?.toDouble(),
      carbsTarget: (json['carbsTarget'] as num?)?.toDouble(),
      sodiumTarget: (json['sodiumTarget'] as num?)?.toDouble(),
      fluidsTarget: (json['fluidsTarget'] as num?)?.toDouble(),
      carbsLowTarget: (json['carbsLowTarget'] as num?)?.toDouble(),
      carbsHighTarget: (json['carbsHighTarget'] as num?)?.toDouble(),
      proteinLowTarget: (json['proteinLowTarget'] as num?)?.toDouble(),
      proteinHighTarget: (json['proteinHighTarget'] as num?)?.toDouble(),
      sodiumLowTarget: (json['sodiumLowTarget'] as num?)?.toDouble(),
      sodiumHighTarget: (json['sodiumHighTarget'] as num?)?.toDouble(),
      fluidsLowTarget: (json['fluidsLowTarget'] as num?)?.toDouble(),
      fluidsHighTarget: (json['fluidsHighTarget'] as num?)?.toDouble(),
      subPhases: subPhases,
      byHourData: byHourData,
      pinDecision: _parsePinDecision(json),
      shortfalls: ((json['shortfalls'] as List<dynamic>?) ?? const [])
          .map((e) => MacroShortfall.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Parse pin_decision from either edge fn (`pin_decision`, snake_case) or
  /// persisted (`pinDecision`, camelCase) JSON shape.
  static PinDecision? _parsePinDecision(Map<String, dynamic> json) {
    final raw = json['pin_decision'] ?? json['pinDecision'];
    if (raw is! Map<String, dynamic>) return null;
    return PinDecision.fromJson(raw);
  }

  /// Create PlanSection from Edge Function format (before/during/after arrays)
  /// [activityType] - Optional activity type for generating correct section titles
  factory PlanSection.fromEdgeFunctionJson(
    String sectionId,
    List<dynamic> items, {
    ActivityType activityType = ActivityType.running,
  }) {
    // Use activity-type-aware section titles
    final String sectionTitle = activityType.getSectionTitle(sectionId);

    final Map<String, String> sectionSubtitles = {
      'before_run': '30-60 min before',
      'after_run': 'Within 30 minutes',
    };

    return PlanSection(
      id: sectionId,
      title: sectionTitle,
      subtitle: sectionSubtitles[sectionId],
      timing: null,
      foodItems: items
          .map(
            (item) =>
                FoodItemData.fromEdgeFunctionJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timing': timing,
      'foodItems': foodItems.map((item) => item.toJson()).toList(),
      'proteinTarget': proteinTarget,
      'fatTarget': fatTarget,
      'carbsTarget': carbsTarget,
      'sodiumTarget': sodiumTarget,
      'fluidsTarget': fluidsTarget,
      'carbsLowTarget': carbsLowTarget,
      'carbsHighTarget': carbsHighTarget,
      'proteinLowTarget': proteinLowTarget,
      'proteinHighTarget': proteinHighTarget,
      'sodiumLowTarget': sodiumLowTarget,
      'sodiumHighTarget': sodiumHighTarget,
      'fluidsLowTarget': fluidsLowTarget,
      'fluidsHighTarget': fluidsHighTarget,
      if (subPhases != null)
        'subPhases': subPhases!.map((sp) => sp.toJson()).toList(),
      if (byHourData != null) 'byHourData': byHourData!.toJson(),
      if (pinDecision != null) 'pinDecision': pinDecision!.toJson(),
      if (shortfalls.isNotEmpty)
        'shortfalls': shortfalls.map((s) => s.toJson()).toList(),
    };
  }

  /// Create a copy with updated values
  PlanSection copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? timing,
    List<FoodItemData>? foodItems,
    double? proteinTarget,
    double? fatTarget,
    double? carbsTarget,
    double? sodiumTarget,
    double? fluidsTarget,
    double? carbsLowTarget,
    double? carbsHighTarget,
    double? proteinLowTarget,
    double? proteinHighTarget,
    double? sodiumLowTarget,
    double? sodiumHighTarget,
    double? fluidsLowTarget,
    double? fluidsHighTarget,
    List<BeforeSubPhase>? subPhases,
    ByHourData? byHourData,
    bool clearByHourData = false,
    PinDecision? pinDecision,
    List<MacroShortfall>? shortfalls,
  }) {
    return PlanSection(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timing: timing ?? this.timing,
      foodItems: foodItems ?? this.foodItems,
      proteinTarget: proteinTarget ?? this.proteinTarget,
      fatTarget: fatTarget ?? this.fatTarget,
      carbsTarget: carbsTarget ?? this.carbsTarget,
      sodiumTarget: sodiumTarget ?? this.sodiumTarget,
      fluidsTarget: fluidsTarget ?? this.fluidsTarget,
      carbsLowTarget: carbsLowTarget ?? this.carbsLowTarget,
      carbsHighTarget: carbsHighTarget ?? this.carbsHighTarget,
      proteinLowTarget: proteinLowTarget ?? this.proteinLowTarget,
      proteinHighTarget: proteinHighTarget ?? this.proteinHighTarget,
      sodiumLowTarget: sodiumLowTarget ?? this.sodiumLowTarget,
      sodiumHighTarget: sodiumHighTarget ?? this.sodiumHighTarget,
      fluidsLowTarget: fluidsLowTarget ?? this.fluidsLowTarget,
      fluidsHighTarget: fluidsHighTarget ?? this.fluidsHighTarget,
      subPhases: subPhases ?? this.subPhases,
      byHourData: clearByHourData ? null : (byHourData ?? this.byHourData),
      pinDecision: pinDecision ?? this.pinDecision,
      shortfalls: shortfalls ?? this.shortfalls,
    );
  }

  /// Get default macro targets for this section type
  static PlanSection withDefaults({
    required String id,
    required String title,
    String? subtitle,
    String? timing,
    List<FoodItemData>? foodItems,
  }) {
    // Default values based on section type
    double? defaultProtein,
        defaultFat,
        defaultCarbs,
        defaultSodium,
        defaultFluids;

    switch (id) {
      case 'before-run':
      case 'pre-run':
        defaultCarbs = 30.0;
        defaultProtein = 5.0;
        defaultFat = 5.0;
        defaultSodium = 200.0;
        defaultFluids = 500.0;
        break;
      case 'during-run':
        defaultCarbs = 45.0;
        defaultProtein = 0.0;
        defaultFat = 0.0;
        defaultSodium = 250.0;
        defaultFluids = 600.0;
        break;
      case 'after-run':
      case 'post-run':
        defaultCarbs = 40.0;
        defaultProtein = 20.0;
        defaultFat = 10.0;
        defaultSodium = 300.0;
        defaultFluids = 500.0;
        break;
      default:
        defaultCarbs = 30.0;
        defaultProtein = 10.0;
        defaultFat = 5.0;
        defaultSodium = 200.0;
        defaultFluids = 500.0;
    }

    return PlanSection(
      id: id,
      title: title,
      subtitle: subtitle,
      timing: timing,
      foodItems: foodItems ?? [],
      proteinTarget: defaultProtein,
      fatTarget: defaultFat,
      carbsTarget: defaultCarbs,
      sodiumTarget: defaultSodium,
      fluidsTarget: defaultFluids,
    );
  }

  @override
  String toString() => 'PlanSection(title: $title, items: ${foodItems.length})';
}
