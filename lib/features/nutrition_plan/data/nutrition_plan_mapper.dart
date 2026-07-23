import 'dart:convert';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_shortfall.dart';
import '../domain/time_slot_assignment.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';

/// Mapper for converting NutritionPlan to/from JSON formats
/// Handles Edge Function JSON and Supabase database JSON formats
class NutritionPlanMapper {
  /// Parse activity ID from various formats (String, int, num)
  static String? _parseActivityId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is num) return value.toString();
    return null;
  }

  /// Create NutritionPlan from Edge Function JSON response
  static NutritionPlan fromJson(Map<String, dynamic> json) {
    return NutritionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((section) => PlanSection.fromJson(section))
          .toList(),
      macroTargets: json['macroTargets'] != null
          ? PlanMacroSummary.fromJson(json['macroTargets'])
          : null,
      totalCalories: json['totalCalories'] as int?,
      notes: json['notes'] as String?,
      runDateTime: json['runDateTime'] != null
          ? DateTime.parse(json['runDateTime'])
          : null,
      planRating: json['planRating'] as int?,
      journalNotes: json['journalNotes'] as String?,
      activityId: _parseActivityId(json['activityId']),
      version: json['version'] as int? ?? 1,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      clientUpdatedAt: json['clientUpdatedAt'] != null
          ? DateTime.parse(json['clientUpdatedAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      conflictResolution:
          json['conflictResolution'] as String? ?? 'last_write_wins',
    );
  }

  /// Create NutritionPlan from Supabase database JSON
  static NutritionPlan fromSupabaseJson(Map<String, dynamic> json) {
    // Handle plan_data which might be a string, Map, or null
    Map<String, dynamic>? planData;
    if (json['plan_data'] is String) {
      try {
        final parsedData = jsonDecode(json['plan_data']);
        planData = parsedData is Map<String, dynamic> ? parsedData : null;
      } catch (e) {
        DebugLogger.error('Error parsing plan_data string: $e');
        planData = null;
      }
    } else if (json['plan_data'] is Map<String, dynamic>) {
      planData = json['plan_data'] as Map<String, dynamic>;
    } else {
      planData = null;
    }

    // Parse sections with error handling
    List<PlanSection> sections = [];
    if (planData != null) {
      // Handle new format: sections array
      if (planData['sections'] is List) {
        try {
          sections = (planData['sections'] as List<dynamic>)
              .map(
                (section) =>
                    PlanSection.fromJson(section as Map<String, dynamic>),
              )
              .toList();
        } catch (e) {
          DebugLogger.error('Error parsing sections from sections array: $e');
          sections = [];
        }
      }
      // Handle legacy format from Edge Function: plan.before/during/after
      else if (planData['plan'] is Map) {
        try {
          final plan = planData['plan'] as Map<String, dynamic>;

          // Detect brick workout V2 response (has during_segments instead of during)
          if (plan.containsKey('during_segments')) {
            sections = _parseBrickV2Plan(plan, planData);
          } else {
            final List<PlanSection> parsedSections = [];

            // Parse "before" section - check for v2 sub-phase format vs v1 flat list
            if (plan['before'] is Map) {
              // V2 format: before is an object with meal/snack/top_up sub-phases
              final beforeMap = plan['before'] as Map<String, dynamic>;
              final List<BeforeSubPhase> subPhases = [];

              for (final key in ['meal', 'snack', 'top_up']) {
                if (beforeMap[key] is Map) {
                  subPhases.add(
                    BeforeSubPhase.fromJson(
                      beforeMap[key] as Map<String, dynamic>,
                    ),
                  );
                }
              }

              parsedSections.add(
                PlanSection(
                  id: 'before_run',
                  title: 'Before Run',
                  subtitle: 'Pre-workout nutrition',
                  foodItems: const [], // Foods live in sub-phases
                  subPhases: subPhases,
                ),
              );
            } else if (plan['before'] is List) {
              // V1 format: before is a flat list of food items
              parsedSections.add(
                PlanSection.fromEdgeFunctionJson(
                  'before_run',
                  plan['before'] as List<dynamic>,
                ),
              );
            }

            // Parse "during" section — V2 may return Map {foods, by_hour_data} or List
            if (plan['during'] is Map) {
              final duringMap = plan['during'] as Map<String, dynamic>;
              final duringFoods = duringMap['foods'] as List<dynamic>? ?? [];
              var section = PlanSection.fromEdgeFunctionJson(
                'during_run',
                duringFoods,
              );
              // Parse byHourData if server provided it
              final byHourJson =
                  duringMap['by_hour_data'] as Map<String, dynamic>?;
              if (byHourJson != null) {
                section = section.copyWith(
                  byHourData: ByHourData.fromJson(byHourJson),
                );
              }
              // Parse pin_decision telemetry (Formula Kit PR 2 substep 9).
              // Present only when pins were supplied to the algorithm.
              final pinDecisionJson =
                  duringMap['pin_decision'] as Map<String, dynamic>?;
              if (pinDecisionJson != null) {
                section = section.copyWith(
                  pinDecision: PinDecision.fromJson(pinDecisionJson),
                );
              }
              // Parse macro shortfalls the solver reported for this phase
              // (bug 3a3e3fdb: previously dropped on the floor, so plans
              // that knowingly missed carb targets showed no explanation).
              // Mirrors BeforeSubPhase.shortfalls; absent or malformed
              // entries are skipped rather than failing the whole parse.
              final shortfallsJson = duringMap['shortfalls'];
              if (shortfallsJson is List) {
                final shortfalls = shortfallsJson
                    .whereType<Map>()
                    .map(
                      (e) =>
                          MacroShortfall.fromJson(Map<String, dynamic>.from(e)),
                    )
                    .toList();
                if (shortfalls.isNotEmpty) {
                  section = section.copyWith(shortfalls: shortfalls);
                }
              }
              parsedSections.add(section);
            } else if (plan['during'] is List) {
              // Backward compat: plain array of food items
              parsedSections.add(
                PlanSection.fromEdgeFunctionJson(
                  'during_run',
                  plan['during'] as List<dynamic>,
                ),
              );
            }

            // Parse "after" section
            // Foods ride under `after` as a flat list (older-client contract);
            // the pin_decision telemetry rides as a sibling key
            // `after_pin_decision` — see generate-nutrition-plan-v3/index.ts.
            // Formula Kit PR 3 substep 9.
            if (plan['after'] is List) {
              var afterSection = PlanSection.fromEdgeFunctionJson(
                'after_run',
                plan['after'] as List<dynamic>,
              );
              final afterPinDecisionJson =
                  plan['after_pin_decision'] as Map<String, dynamic>?;
              if (afterPinDecisionJson != null) {
                afterSection = afterSection.copyWith(
                  pinDecision: PinDecision.fromJson(afterPinDecisionJson),
                );
              }
              parsedSections.add(afterSection);
            }

            // Apply per-phase targets from macro_targets (snake_case from V2 edge function)
            // Use Map.from() to guarantee Map<String, dynamic> runtime type
            final macroTargetsMap = planData['macro_targets'] is Map
                ? Map<String, dynamic>.from(planData['macro_targets'] as Map)
                : null;
            DebugLogger.info(
              '🎯 OVERRIDE DEBUG [3/5]: fromSupabaseJson - macro_targets found=${macroTargetsMap != null}, '
              'planData keys=${planData.keys.toList()}, '
              'pre_run type=${macroTargetsMap?['pre_run']?.runtimeType}, '
              'during_run type=${macroTargetsMap?['during_run']?.runtimeType}, '
              'post_run type=${macroTargetsMap?['post_run']?.runtimeType}',
            );
            if (macroTargetsMap != null) {
              sections = parsedSections.map((section) {
                Map<String, dynamic>? phaseTargets;
                final rawTargets = section.id == 'before_run'
                    ? macroTargetsMap['pre_run']
                    : section.id == 'during_run'
                    ? macroTargetsMap['during_run']
                    : section.id == 'after_run'
                    ? macroTargetsMap['post_run']
                    : null;
                if (rawTargets is Map) {
                  phaseTargets = Map<String, dynamic>.from(rawTargets);
                }
                if (phaseTargets != null) {
                  DebugLogger.info(
                    '🎯 OVERRIDE DEBUG [3/5]: Applying targets to section ${section.id}: '
                    'carbs=${phaseTargets['carbs_g']}, protein=${phaseTargets['protein_g']}, '
                    'sodium=${phaseTargets['sodium_mg']}, fluids=${phaseTargets['water_ml']}',
                  );
                  return section.copyWith(
                    carbsTarget: (phaseTargets['carbs_g'] as num?)?.toDouble(),
                    proteinTarget: (phaseTargets['protein_g'] as num?)
                        ?.toDouble(),
                    fatTarget: (phaseTargets['fat_g'] as num?)?.toDouble(),
                    sodiumTarget: (phaseTargets['sodium_mg'] as num?)
                        ?.toDouble(),
                    fluidsTarget: (phaseTargets['water_ml'] as num?)
                        ?.toDouble(),
                    carbsLowTarget: (phaseTargets['carbs_low_g'] as num?)
                        ?.toDouble(),
                    carbsHighTarget: (phaseTargets['carbs_high_g'] as num?)
                        ?.toDouble(),
                    proteinLowTarget: (phaseTargets['protein_low_g'] as num?)
                        ?.toDouble(),
                    proteinHighTarget: (phaseTargets['protein_high_g'] as num?)
                        ?.toDouble(),
                    sodiumLowTarget: (phaseTargets['sodium_low_mg'] as num?)
                        ?.toDouble(),
                    sodiumHighTarget: (phaseTargets['sodium_high_mg'] as num?)
                        ?.toDouble(),
                    fluidsLowTarget: (phaseTargets['water_low_ml'] as num?)
                        ?.toDouble(),
                    fluidsHighTarget: (phaseTargets['water_high_ml'] as num?)
                        ?.toDouble(),
                  );
                }
                DebugLogger.info(
                  '🎯 OVERRIDE DEBUG [3/5]: No phaseTargets for section ${section.id}',
                );
                return section;
              }).toList();
            } else {
              DebugLogger.info(
                '🎯 OVERRIDE DEBUG [3/5]: macro_targets NOT found in planData - targets will be null!',
              );
              sections = parsedSections;
            }
            DebugLogger.info(
              '✅ Parsed ${sections.length} sections from Edge Function format',
            );
          } // end of non-brick else block
        } catch (e) {
          DebugLogger.error(
            'Error parsing sections from Edge Function format: $e',
          );
          sections = [];
        }
      }
    }

    // Parse macro targets with error handling (try camelCase first, then snake_case)
    PlanMacroSummary? macroTargets;
    if (planData != null && planData['macroTargets'] is Map) {
      try {
        macroTargets = PlanMacroSummary.fromJson(
          planData['macroTargets'] as Map<String, dynamic>,
        );
      } catch (e) {
        DebugLogger.error('Error parsing macroTargets: $e');
        macroTargets = null;
      }
    }
    // Fallback: build PlanMacroSummary from snake_case macro_targets (V2 edge function)
    if (macroTargets == null &&
        planData != null &&
        planData['macro_targets'] is Map) {
      try {
        // Use Map.from() to ensure Map<String, dynamic> runtime type — JSON-decoded
        // maps can have inferred value types that cause 'is not a subtype' errors.
        final mt = Map<String, dynamic>.from(planData['macro_targets'] as Map);
        final pre = mt['pre_run'] is Map
            ? Map<String, dynamic>.from(mt['pre_run'] as Map)
            : <String, dynamic>{};
        final post = mt['post_run'] is Map
            ? Map<String, dynamic>.from(mt['post_run'] as Map)
            : <String, dynamic>{};

        // Check for brick format with phases structure
        num duringCarbs = 0;
        num duringSodium = 0;
        if (mt['phases'] is Map) {
          final phases = mt['phases'] as Map<String, dynamic>;
          // Sum across during_segments + transitions
          final duringSegs = phases['during_segments'] as List<dynamic>? ?? [];
          for (final seg in duringSegs) {
            if (seg is Map<String, dynamic>) {
              duringCarbs += (seg['carbs_g'] as num?) ?? 0;
              duringSodium += (seg['sodium_mg'] as num?) ?? 0;
            }
          }
          final trans = phases['transitions'] as List<dynamic>? ?? [];
          for (final t in trans) {
            if (t is Map<String, dynamic>) {
              duringCarbs += (t['carbs_g'] as num?) ?? 0;
              duringSodium += (t['sodium_mg'] as num?) ?? 0;
            }
          }
        } else {
          final during = mt['during_run'] is Map
              ? Map<String, dynamic>.from(mt['during_run'] as Map)
              : <String, dynamic>{};
          duringCarbs = (during['carbs_g'] as num?) ?? 0;
          duringSodium = (during['sodium_mg'] as num?) ?? 0;
        }

        // Sum across all phases for the overall summary
        final totalCarbs =
            ((pre['carbs_g'] as num?) ?? 0) +
            duringCarbs +
            ((post['carbs_g'] as num?) ?? 0);
        final totalProtein =
            ((pre['protein_g'] as num?) ?? 0) +
            ((post['protein_g'] as num?) ?? 0);
        final totalFat =
            ((pre['fat_g'] as num?) ?? 0) + ((post['fat_g'] as num?) ?? 0);
        final totalSodium =
            ((pre['sodium_mg'] as num?) ?? 0) +
            duringSodium +
            ((post['sodium_mg'] as num?) ?? 0);
        final totalCalories = (totalCarbs * 4 + totalProtein * 4 + totalFat * 9)
            .round();
        // Extract pre-workout range fields (V4)
        final preSodiumLow = pre['sodium_low_mg'] as num?;
        final preSodiumHigh = pre['sodium_high_mg'] as num?;
        final preFluidsLow = pre['water_low_ml'] as num?;
        final preFluidsHigh = pre['water_high_ml'] as num?;

        macroTargets = PlanMacroSummary(
          calories: totalCalories,
          carbs: totalCarbs.round(),
          protein: totalProtein.round(),
          fat: totalFat.round(),
          sodium: totalSodium.round(),
          sodiumMin: preSodiumLow?.round(),
          sodiumMax: preSodiumHigh?.round(),
          fluidsMin: preFluidsLow != null
              ? (preFluidsLow * 0.033814).round()
              : null,
          fluidsMax: preFluidsHigh != null
              ? (preFluidsHigh * 0.033814).round()
              : null,
        );
      } catch (e) {
        DebugLogger.error('Error parsing macro_targets (snake_case): $e');
      }
    }

    return NutritionPlan(
      id: json['plan_id'] as String,
      name: json['plan_name'] as String,
      sections: sections,
      macroTargets: macroTargets,
      totalCalories: json['total_calories'] is num
          ? (json['total_calories'] as num).toInt()
          : null,
      notes: json['notes'] as String?,
      runDateTime: json['run_date_time'] is String
          ? DateTime.tryParse(json['run_date_time'])
          : null,
      planRating: json['plan_rating'] is num
          ? (json['plan_rating'] as num).toInt()
          : null,
      journalNotes: json['journal_notes'] as String?,
      activityId: _parseActivityId(
        json['activity_id'] ?? planData?['activityId'],
      ),
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      lastModifiedBy: json['last_modified_by'] as String?,
      clientUpdatedAt: json['client_updated_at'] is String
          ? DateTime.tryParse(json['client_updated_at'])
          : null,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'])
          : null,
      isDeleted: json['is_deleted'] is bool
          ? json['is_deleted'] as bool
          : false,
      conflictResolution:
          json['conflict_resolution'] as String? ?? 'last_write_wins',
    );
  }

  /// Parse brick V2 response into PlanSections.
  /// Handles before (with sub-phases), during_segments, transitions, and after.
  static List<PlanSection> _parseBrickV2Plan(
    Map<String, dynamic> plan,
    Map<String, dynamic> planData,
  ) {
    final sections = <PlanSection>[];
    final macroTargetsMap = planData['macro_targets'] is Map
        ? Map<String, dynamic>.from(planData['macro_targets'] as Map)
        : null;
    final phases = macroTargetsMap?['phases'] is Map
        ? Map<String, dynamic>.from(macroTargetsMap!['phases'] as Map)
        : null;

    // 1. Before Brick — parse V2 sub-phases (meal/snack/top_up) or V1 flat list
    DebugLogger.info(
      'Brick V2: plan keys=${plan.keys.toList()}, before type=${plan['before'].runtimeType}',
    );
    if (plan['before'] is Map) {
      final beforeMap = plan['before'] as Map<String, dynamic>;
      final subPhases = <BeforeSubPhase>[];

      DebugLogger.info('Brick V2: before keys=${beforeMap.keys.toList()}');

      for (final key in ['meal', 'snack', 'top_up']) {
        if (beforeMap[key] is Map) {
          subPhases.add(
            BeforeSubPhase.fromJson(beforeMap[key] as Map<String, dynamic>),
          );
        }
      }

      // Apply before targets from phases or pre_run
      final rawBeforeTargets = phases?['before'] ?? macroTargetsMap?['pre_run'];
      final beforeTargets = rawBeforeTargets is Map
          ? Map<String, dynamic>.from(rawBeforeTargets)
          : null;

      sections.add(
        PlanSection(
          id: 'before',
          title: 'Before Brick',
          subtitle: 'Pre-workout nutrition',
          foodItems: const [],
          subPhases: subPhases,
          carbsTarget: (beforeTargets?['carbs_g'] as num?)?.toDouble(),
          proteinTarget: (beforeTargets?['protein_g'] as num?)?.toDouble(),
          fatTarget: (beforeTargets?['fat_g'] as num?)?.toDouble(),
          sodiumTarget: (beforeTargets?['sodium_mg'] as num?)?.toDouble(),
          fluidsTarget: (beforeTargets?['water_ml'] as num?)?.toDouble(),
          carbsLowTarget: (beforeTargets?['carbs_low_g'] as num?)?.toDouble(),
          carbsHighTarget: (beforeTargets?['carbs_high_g'] as num?)?.toDouble(),
          proteinLowTarget: (beforeTargets?['protein_low_g'] as num?)
              ?.toDouble(),
          proteinHighTarget: (beforeTargets?['protein_high_g'] as num?)
              ?.toDouble(),
          sodiumLowTarget: (beforeTargets?['sodium_low_mg'] as num?)
              ?.toDouble(),
          sodiumHighTarget: (beforeTargets?['sodium_high_mg'] as num?)
              ?.toDouble(),
          fluidsLowTarget: (beforeTargets?['water_low_ml'] as num?)?.toDouble(),
          fluidsHighTarget: (beforeTargets?['water_high_ml'] as num?)
              ?.toDouble(),
        ),
      );
    } else if (plan['before'] is List) {
      final rawBt = phases?['before'] ?? macroTargetsMap?['pre_run'];
      final beforeTargets = rawBt is Map
          ? Map<String, dynamic>.from(rawBt)
          : null;
      sections.add(
        PlanSection(
          id: 'before',
          title: 'Before Brick',
          subtitle: 'Pre-workout nutrition',
          foodItems: (plan['before'] as List<dynamic>)
              .map(
                (item) => FoodItemData.fromEdgeFunctionJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
          carbsTarget: (beforeTargets?['carbs_g'] as num?)?.toDouble(),
          proteinTarget: (beforeTargets?['protein_g'] as num?)?.toDouble(),
          fatTarget: (beforeTargets?['fat_g'] as num?)?.toDouble(),
          sodiumTarget: (beforeTargets?['sodium_mg'] as num?)?.toDouble(),
          fluidsTarget: (beforeTargets?['water_ml'] as num?)?.toDouble(),
          carbsLowTarget: (beforeTargets?['carbs_low_g'] as num?)?.toDouble(),
          carbsHighTarget: (beforeTargets?['carbs_high_g'] as num?)?.toDouble(),
          proteinLowTarget: (beforeTargets?['protein_low_g'] as num?)
              ?.toDouble(),
          proteinHighTarget: (beforeTargets?['protein_high_g'] as num?)
              ?.toDouble(),
          sodiumLowTarget: (beforeTargets?['sodium_low_mg'] as num?)
              ?.toDouble(),
          sodiumHighTarget: (beforeTargets?['sodium_high_mg'] as num?)
              ?.toDouble(),
          fluidsLowTarget: (beforeTargets?['water_low_ml'] as num?)?.toDouble(),
          fluidsHighTarget: (beforeTargets?['water_high_ml'] as num?)
              ?.toDouble(),
        ),
      );
    }

    // 2. During segments + interleaved transitions
    final duringSegmentsData =
        plan['during_segments'] as Map<String, dynamic>? ?? {};
    final transitionsData = plan['transitions'] as Map<String, dynamic>? ?? {};

    // Build segment targets map from phases.during_segments
    final segmentTargetsMap = <int, Map<String, dynamic>>{};
    final segmentTargetsList =
        phases?['during_segments'] as List<dynamic>? ?? [];
    for (final seg in segmentTargetsList) {
      if (seg is Map<String, dynamic>) {
        final order = seg['segment_order'] as int?;
        if (order != null) segmentTargetsMap[order] = seg;
      }
    }

    // Build transition targets map from phases.transitions
    final transitionTargetsMap = <String, Map<String, dynamic>>{};
    final transitionTargetsList =
        phases?['transitions'] as List<dynamic>? ?? [];
    for (final t in transitionTargetsList) {
      if (t is Map<String, dynamic>) {
        final name = t['transition_name'] as String?;
        if (name != null) transitionTargetsMap[name] = t;
      }
    }

    int segmentIndex = 0;
    for (final entry in duringSegmentsData.entries) {
      final segmentOrder = entry.key;
      final segmentItems = entry.value as List<dynamic>? ?? [];
      final orderInt = int.tryParse(segmentOrder) ?? (segmentIndex + 1);

      // Resolve sport display name from segment targets
      final segTargets = segmentTargetsMap[orderInt];
      final sport = segTargets?['sport'] as String? ?? 'unknown';
      final sportName = _getSportDisplayName(sport);

      final foodItems = segmentItems
          .map(
            (item) =>
                FoodItemData.fromEdgeFunctionJson(item as Map<String, dynamic>),
          )
          .toList();

      sections.add(
        PlanSection(
          id: 'during_segment_$segmentOrder',
          title: 'During $sportName',
          subtitle: null,
          foodItems: foodItems,
          carbsTarget: (segTargets?['carbs_g'] as num?)?.toDouble(),
          sodiumTarget: (segTargets?['sodium_mg'] as num?)?.toDouble(),
          fluidsTarget: (segTargets?['water_ml'] as num?)?.toDouble(),
          carbsLowTarget: (segTargets?['carbs_low_g'] as num?)?.toDouble(),
          carbsHighTarget: (segTargets?['carbs_high_g'] as num?)?.toDouble(),
          sodiumLowTarget: (segTargets?['sodium_low_mg'] as num?)?.toDouble(),
          sodiumHighTarget: (segTargets?['sodium_high_mg'] as num?)?.toDouble(),
          fluidsLowTarget: (segTargets?['water_low_ml'] as num?)?.toDouble(),
          fluidsHighTarget: (segTargets?['water_high_ml'] as num?)?.toDouble(),
        ),
      );

      // Add transition after each segment (except the last)
      final transitionKey = 'T${segmentIndex + 1}';
      if (transitionsData.containsKey(transitionKey)) {
        final transitionItems =
            transitionsData[transitionKey] as List<dynamic>? ?? [];
        final transTargets = transitionTargetsMap[transitionKey];

        sections.add(
          PlanSection(
            id: transitionKey,
            title: 'Transition ($transitionKey)',
            subtitle: 'Quick refuel between segments',
            foodItems: transitionItems
                .map(
                  (item) => FoodItemData.fromEdgeFunctionJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(),
            carbsTarget: (transTargets?['carbs_g'] as num?)?.toDouble(),
            sodiumTarget: (transTargets?['sodium_mg'] as num?)?.toDouble(),
            fluidsTarget: (transTargets?['water_ml'] as num?)?.toDouble(),
            carbsLowTarget: (transTargets?['carbs_low_g'] as num?)?.toDouble(),
            carbsHighTarget: (transTargets?['carbs_high_g'] as num?)
                ?.toDouble(),
            sodiumLowTarget: (transTargets?['sodium_low_mg'] as num?)
                ?.toDouble(),
            sodiumHighTarget: (transTargets?['sodium_high_mg'] as num?)
                ?.toDouble(),
            fluidsLowTarget: (transTargets?['water_low_ml'] as num?)
                ?.toDouble(),
            fluidsHighTarget: (transTargets?['water_high_ml'] as num?)
                ?.toDouble(),
          ),
        );
      }

      segmentIndex++;
    }

    // 3. After Brick
    if (plan['after'] is List) {
      final rawAt = phases?['after'] ?? macroTargetsMap?['post_run'];
      final afterTargets = rawAt is Map
          ? Map<String, dynamic>.from(rawAt)
          : null;

      sections.add(
        PlanSection(
          id: 'after',
          title: 'After Brick',
          subtitle: 'Within 30-60 minutes post-workout',
          foodItems: (plan['after'] as List<dynamic>)
              .map(
                (item) => FoodItemData.fromEdgeFunctionJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
          carbsTarget: (afterTargets?['carbs_g'] as num?)?.toDouble(),
          proteinTarget: (afterTargets?['protein_g'] as num?)?.toDouble(),
          sodiumTarget: (afterTargets?['sodium_mg'] as num?)?.toDouble(),
          fluidsTarget: (afterTargets?['water_ml'] as num?)?.toDouble(),
          carbsLowTarget: (afterTargets?['carbs_low_g'] as num?)?.toDouble(),
          carbsHighTarget: (afterTargets?['carbs_high_g'] as num?)?.toDouble(),
          proteinLowTarget: (afterTargets?['protein_low_g'] as num?)
              ?.toDouble(),
          proteinHighTarget: (afterTargets?['protein_high_g'] as num?)
              ?.toDouble(),
          sodiumLowTarget: (afterTargets?['sodium_low_mg'] as num?)?.toDouble(),
          sodiumHighTarget: (afterTargets?['sodium_high_mg'] as num?)
              ?.toDouble(),
          fluidsLowTarget: (afterTargets?['water_low_ml'] as num?)?.toDouble(),
          fluidsHighTarget: (afterTargets?['water_high_ml'] as num?)
              ?.toDouble(),
        ),
      );
    }

    DebugLogger.info(
      'Brick V2: ${sections.length} sections in order: ${sections.map((s) => s.title).toList()}',
    );

    return sections;
  }

  /// Get display name for a sport type (used by brick V2 parsing)
  static String _getSportDisplayName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'Swim';
      case 'cycling':
        return 'Bike';
      case 'running':
        return 'Run';
      default:
        return sport.substring(0, 1).toUpperCase() + sport.substring(1);
    }
  }

  /// Convert NutritionPlan to JSON for API calls
  static Map<String, dynamic> toJson(NutritionPlan plan) {
    return {
      'id': plan.id,
      'name': plan.name,
      'sections': plan.sections.map((s) => s.toJson()).toList(),
      'macroTargets': plan.macroTargets?.toJson(),
      'totalCalories': plan.totalCalories,
      'notes': plan.notes,
      'runDateTime': plan.runDateTime?.toIso8601String(),
      'planRating': plan.planRating,
      'journalNotes': plan.journalNotes,
      'activityId': plan.activityId,
      'version': plan.version,
      'lastModifiedBy': plan.lastModifiedBy,
      'clientUpdatedAt': plan.clientUpdatedAt?.toIso8601String(),
      'createdAt': plan.createdAt?.toIso8601String(),
      'updatedAt': plan.updatedAt?.toIso8601String(),
      'isDeleted': plan.isDeleted,
      'conflictResolution': plan.conflictResolution,
    };
  }
}
