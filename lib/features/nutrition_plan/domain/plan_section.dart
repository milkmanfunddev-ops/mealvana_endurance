import 'food_item_data.dart';
import 'time_slot_assignment.dart';
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

  /// Display title for this sub-phase
  String get displayTitle {
    switch (subPhaseType) {
      case 'meal':
        return 'Full Meal';
      case 'snack':
        return 'Pre-Workout Snack';
      case 'top_up':
        return 'Top-Off';
      default:
        return subPhaseType;
    }
  }

  /// Auto-generated summary of foods in this sub-phase (for collapsed display)
  String get templateSummary {
    if (foodItems.isEmpty) return templateName ?? '';

    return foodItems
        .map((f) {
          final match = RegExp(
            r'^([\d.]+)\s*(.*)$',
          ).firstMatch(f.quantity.trim());
          final numericQty = match != null
              ? double.tryParse(match.group(1)!)
              : null;
          final tail = match?.group(2)?.trim() ?? '';

          final baseName = _simplifyName(f.displayName ?? f.name);

          if (numericQty == null) return baseName;

          final qtyStr = (numericQty - numericQty.roundToDouble()).abs() < 0.01
              ? numericQty.round().toString()
              : numericQty.toStringAsFixed(
                  (numericQty * 10 - (numericQty * 10).round()).abs() < 0.01
                      ? 1
                      : 2,
                );

          if ((numericQty - 1.0).abs() < 0.01) {
            // For qty=1 prefer the clean food name (baseName) over the tail
            // which may include a serving unit prefix (e.g. "packet Energy Chews").
            return baseName;
          }

          // If quantity has a multi-word tail (e.g. "cups Oatmeal"), use it
          if (tail.contains(' ')) {
            return '$qtyStr ${_simplifyName(tail)}';
          }

          final pluralName = _simplifyName(
            f.displayNamePlural ??
                (baseName.toLowerCase().endsWith('s')
                    ? baseName
                    : '${baseName}s'),
          );
          return '$qtyStr $pluralName';
        })
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
    );
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
    this.subPhases,
    this.byHourData,
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

  /// Nested sub-phases for template-based "before" sections.
  /// When present, foodItems list is empty (foods live in sub-phases instead).
  final List<BeforeSubPhase>? subPhases;

  /// By-hour time slot assignments for during-activity sections.
  /// Lazily initialized on first "By Hour" toggle for qualifying sections.
  final ByHourData? byHourData;

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
      subPhases: subPhases,
      byHourData: byHourData,
    );
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
      if (subPhases != null)
        'subPhases': subPhases!.map((sp) => sp.toJson()).toList(),
      if (byHourData != null) 'byHourData': byHourData!.toJson(),
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
    List<BeforeSubPhase>? subPhases,
    ByHourData? byHourData,
    bool clearByHourData = false,
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
      subPhases: subPhases ?? this.subPhases,
      byHourData: clearByHourData ? null : (byHourData ?? this.byHourData),
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
