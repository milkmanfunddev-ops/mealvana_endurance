import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/sync/data_sync_service.dart';
import '../../../nutrition_plan/domain/fuel_log_data.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';

part 'coach_reports_controller.g.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Macro totals for a single plan section (before/during/after)
class SectionMacros {
  final int carbs;
  final int protein;
  final int fat;
  final int? calories;

  const SectionMacros({
    this.carbs = 0,
    this.protein = 0,
    this.fat = 0,
    this.calories,
  });

  int get estimatedCalories => calories ?? (carbs * 4 + protein * 4 + fat * 9);
}

/// Per-activity report row
class ActivityReportItem {
  final String activityId;
  final String name;
  final String activityType;
  final DateTime scheduledDate;
  final int? durationMinutes;
  final double? distanceMiles;
  final String status;
  final bool isCompleted;

  // Planned nutrition
  final SectionMacros? plannedBefore;
  final SectionMacros? plannedDuring;
  final SectionMacros? plannedAfter;
  final int? plannedTotalCarbs;
  final int? plannedTotalCalories;

  // Actual nutrition (from fuel log)
  final SectionMacros? actualBefore;
  final SectionMacros? actualDuring;
  final SectionMacros? actualAfter;
  final int? actualTotalCarbs;
  final int? actualTotalCalories;

  // Feedback
  final bool hasFuelLog;
  final int? satisfactionRating;
  final int? nutritionRating;
  final String? notes;

  const ActivityReportItem({
    required this.activityId,
    required this.name,
    required this.activityType,
    required this.scheduledDate,
    this.durationMinutes,
    this.distanceMiles,
    this.status = 'planned',
    this.isCompleted = false,
    this.plannedBefore,
    this.plannedDuring,
    this.plannedAfter,
    this.plannedTotalCarbs,
    this.plannedTotalCalories,
    this.actualBefore,
    this.actualDuring,
    this.actualAfter,
    this.actualTotalCarbs,
    this.actualTotalCalories,
    this.hasFuelLog = false,
    this.satisfactionRating,
    this.nutritionRating,
    this.notes,
  });

  double? get adherence {
    if (!hasFuelLog ||
        plannedTotalCalories == null ||
        plannedTotalCalories == 0 ||
        actualTotalCalories == null) {
      return null;
    }
    return (actualTotalCalories! / plannedTotalCalories!).clamp(0.0, 2.0);
  }
}

/// Compact overview row for triage table
class AthleteOverview {
  final CoachAthleteRelationship relationship;
  final int activitiesPlanned;
  final int activitiesCompleted;
  final int fuelLogsCount;
  final double? avgAdherence;
  final String? nextEventName;
  final DateTime? nextEventDate;
  final String? lastCompletedActivityName;
  final DateTime? lastCompletedDate;

  const AthleteOverview({
    required this.relationship,
    this.activitiesPlanned = 0,
    this.activitiesCompleted = 0,
    this.fuelLogsCount = 0,
    this.avgAdherence,
    this.nextEventName,
    this.nextEventDate,
    this.lastCompletedActivityName,
    this.lastCompletedDate,
  });
}

/// Full detail report for a single athlete
class AthleteDetailReport {
  final CoachAthleteRelationship relationship;
  final int activitiesPlanned;
  final int activitiesCompleted;
  final int fuelLogsCount;
  final double? avgAdherence;
  final String? nextEventName;
  final DateTime? nextEventDate;
  final List<ActivityReportItem> activities;

  const AthleteDetailReport({
    required this.relationship,
    this.activitiesPlanned = 0,
    this.activitiesCompleted = 0,
    this.fuelLogsCount = 0,
    this.avgAdherence,
    this.nextEventName,
    this.nextEventDate,
    this.activities = const [],
  });
}

/// State for the reports panel
class CoachReportsState {
  final List<AthleteOverview> overviews;
  final AthleteDetailReport? selectedReport;
  final String? selectedRelationshipId;
  final ReportsDateRange dateRange;

  const CoachReportsState({
    this.overviews = const [],
    this.selectedReport,
    this.selectedRelationshipId,
    this.dateRange = const ReportsDateRange.thisWeek(),
  });

  bool get isTriageView => selectedRelationshipId == null;

  CoachReportsState copyWith({
    List<AthleteOverview>? overviews,
    AthleteDetailReport? selectedReport,
    String? selectedRelationshipId,
    ReportsDateRange? dateRange,
    bool clearSelectedReport = false,
    bool clearSelectedRelationshipId = false,
  }) {
    return CoachReportsState(
      overviews: overviews ?? this.overviews,
      selectedReport: clearSelectedReport
          ? null
          : (selectedReport ?? this.selectedReport),
      selectedRelationshipId: clearSelectedRelationshipId
          ? null
          : (selectedRelationshipId ?? this.selectedRelationshipId),
      dateRange: dateRange ?? this.dateRange,
    );
  }
}

// ---------------------------------------------------------------------------
// Date range
// ---------------------------------------------------------------------------

enum ReportsDateRangeType { thisWeek, lastWeek, custom }

class ReportsDateRange {
  final ReportsDateRangeType type;
  final DateTime? _customStart;
  final DateTime? _customEnd;

  const ReportsDateRange.thisWeek()
    : type = ReportsDateRangeType.thisWeek,
      _customStart = null,
      _customEnd = null;

  const ReportsDateRange.lastWeek()
    : type = ReportsDateRangeType.lastWeek,
      _customStart = null,
      _customEnd = null;

  ReportsDateRange.custom(DateTime start, DateTime end)
    : type = ReportsDateRangeType.custom,
      _customStart = DateTime(start.year, start.month, start.day),
      _customEnd = DateTime(
        end.year,
        end.month,
        end.day,
      ).add(const Duration(days: 1));

  DateTime get resolvedStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday;
    switch (type) {
      case ReportsDateRangeType.thisWeek:
        return today.subtract(Duration(days: weekday - 1));
      case ReportsDateRangeType.lastWeek:
        return today.subtract(Duration(days: weekday + 6));
      case ReportsDateRangeType.custom:
        return _customStart!;
    }
  }

  DateTime get resolvedEnd {
    switch (type) {
      case ReportsDateRangeType.thisWeek:
      case ReportsDateRangeType.lastWeek:
        return resolvedStart.add(const Duration(days: 7));
      case ReportsDateRangeType.custom:
        return _customEnd!;
    }
  }

  String get label {
    switch (type) {
      case ReportsDateRangeType.thisWeek:
        return 'This Week';
      case ReportsDateRangeType.lastWeek:
        return 'Last Week';
      case ReportsDateRangeType.custom:
        return '${_customStart!.month}/${_customStart!.day} – ${_customEnd!.month}/${_customEnd!.day}';
    }
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@riverpod
class CoachReportsController extends _$CoachReportsController {
  CoachService get _coachService => ref.read(coachServiceProvider);
  DataSyncService get _syncService => ref.read(dataSyncServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<CoachReportsState> build() async {
    return _loadTriageOverview(const ReportsDateRange.thisWeek());
  }

  /// Load compact overview for all athletes (triage view)
  Future<CoachReportsState> _loadTriageOverview(ReportsDateRange range) async {
    final athletes = await _coachService.getMyAthletes();
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Sync all athletes in parallel
    await Future.wait(
      athletes
          .where((a) => a.athleteUserId.isNotEmpty)
          .map((a) => _syncService.syncAthleteData(a.athleteUserId)),
    ).catchError((e) {
      _logger.warning(
        'Some athlete syncs failed',
        context: 'COACH_REPORTS',
        error: e,
      );
      return <void>[];
    });

    final overviews = <AthleteOverview>[];

    for (final athlete in athletes) {
      final athleteId = athlete.athleteUserId;
      if (athleteId.isEmpty) continue;

      try {
        final activities =
            await (db.select(db.activitiesTable)..where(
                  (t) =>
                      t.userId.equals(athleteId) &
                      t.deletedAt.isNull() &
                      t.scheduledDateTime.isBiggerOrEqualValue(
                        range.resolvedStart,
                      ) &
                      t.scheduledDateTime.isSmallerThanValue(range.resolvedEnd),
                ))
                .get();

        final planned = activities.length;
        final completed = activities
            .where((a) => a.completedAt != null || a.status == 'completed')
            .length;

        // Count fuel logs
        final fuelLogsCount = activities
            .where(
              (a) => a.fuelLogData != null && a.fuelLogData!.trim().isNotEmpty,
            )
            .length;

        // Compute avg adherence from fuel logs
        double? avgAdherence;
        final adherenceValues = <double>[];
        for (final a in activities) {
          if (a.fuelLogData == null || a.fuelLogData!.trim().isEmpty) {
            continue;
          }
          if (a.nutritionPlanData == null ||
              a.nutritionPlanData!.trim().isEmpty) {
            continue;
          }
          final planned = _extractPlannedCalories(a.nutritionPlanData!);
          final actual = _extractActualCalories(a.fuelLogData!);
          if (planned != null && planned > 0 && actual != null) {
            adherenceValues.add((actual / planned).clamp(0.0, 2.0));
          }
        }
        if (adherenceValues.isNotEmpty) {
          avgAdherence =
              adherenceValues.reduce((a, b) => a + b) / adherenceValues.length;
        }

        // Upcoming events (next event, no upper bound)
        final events =
            await (db.select(db.eventsTable)
                  ..where(
                    (t) =>
                        t.userId.equals(athleteId) &
                        t.eventDate.isBiggerOrEqualValue(today),
                  )
                  ..orderBy([(t) => OrderingTerm.asc(t.eventDate)])
                  ..limit(1))
                .get();

        // Last completed activity (across all time, not just date range)
        final lastCompleted =
            await (db.select(db.activitiesTable)
                  ..where(
                    (t) =>
                        t.userId.equals(athleteId) &
                        t.deletedAt.isNull() &
                        (t.completedAt.isNotNull() |
                            t.status.equals('completed')),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.scheduledDateTime)])
                  ..limit(1))
                .getSingleOrNull();

        overviews.add(
          AthleteOverview(
            relationship: athlete,
            activitiesPlanned: planned,
            activitiesCompleted: completed,
            fuelLogsCount: fuelLogsCount,
            avgAdherence: avgAdherence,
            nextEventName: events.isNotEmpty ? events.first.eventName : null,
            nextEventDate: events.isNotEmpty ? events.first.eventDate : null,
            lastCompletedActivityName: lastCompleted?.title,
            lastCompletedDate:
                lastCompleted?.completedAt ??
                (lastCompleted != null
                    ? lastCompleted.scheduledDateTime
                    : null),
          ),
        );
      } catch (e) {
        _logger.warning(
          'Failed to load overview for $athleteId',
          context: 'COACH_REPORTS',
          error: e,
        );
        overviews.add(AthleteOverview(relationship: athlete));
      }
    }

    return CoachReportsState(overviews: overviews, dateRange: range);
  }

  /// Load detailed report for a specific athlete
  Future<AthleteDetailReport> _loadAthleteDetail(
    CoachAthleteRelationship athlete,
    ReportsDateRange range,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final athleteId = athlete.athleteUserId;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Sync this athlete's data
    await _syncService.syncAthleteData(athleteId).catchError((e) {
      _logger.warning(
        'Sync failed for $athleteId',
        context: 'COACH_REPORTS',
        error: e,
      );
    });

    final activities =
        await (db.select(db.activitiesTable)
              ..where(
                (t) =>
                    t.userId.equals(athleteId) &
                    t.deletedAt.isNull() &
                    t.scheduledDateTime.isBiggerOrEqualValue(
                      range.resolvedStart,
                    ) &
                    t.scheduledDateTime.isSmallerThanValue(range.resolvedEnd),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.scheduledDateTime)]))
            .get();

    final activityItems = <ActivityReportItem>[];
    final adherenceValues = <double>[];
    int fuelLogsCount = 0;

    for (final a in activities) {
      final isCompleted = a.completedAt != null || a.status == 'completed';
      final hasFuelLog =
          a.fuelLogData != null && a.fuelLogData!.trim().isNotEmpty;
      if (hasFuelLog) fuelLogsCount++;

      // Parse planned nutrition
      SectionMacros? plannedBefore, plannedDuring, plannedAfter;
      int? plannedTotalCarbs, plannedTotalCalories;

      if (a.nutritionPlanData != null &&
          a.nutritionPlanData!.trim().isNotEmpty) {
        final planMap = _parseJson(a.nutritionPlanData!);
        if (planMap != null) {
          final sections = _parseSections(planMap);
          plannedBefore = sections['before_run'];
          plannedDuring = sections['during_run'];
          plannedAfter = sections['after_run'];

          // Use macroTargets if available, otherwise sum sections
          final macroTargets = planMap['macroTargets'];
          if (macroTargets is Map<String, dynamic>) {
            plannedTotalCarbs = (macroTargets['carbs'] as num?)?.toInt();
            plannedTotalCalories = (macroTargets['calories'] as num?)?.toInt();
          }
          plannedTotalCarbs ??=
              (plannedBefore?.carbs ?? 0) +
              (plannedDuring?.carbs ?? 0) +
              (plannedAfter?.carbs ?? 0);
          plannedTotalCalories ??=
              (plannedBefore?.estimatedCalories ?? 0) +
              (plannedDuring?.estimatedCalories ?? 0) +
              (plannedAfter?.estimatedCalories ?? 0);
          if (plannedTotalCalories == 0) plannedTotalCalories = null;
        }
      }

      // Parse actual nutrition from fuel log
      SectionMacros? actualBefore, actualDuring, actualAfter;
      int? actualTotalCarbs, actualTotalCalories;
      int? satisfactionRating, nutritionRating;
      String? notes;

      if (hasFuelLog) {
        final fuelMap = _parseJson(a.fuelLogData!);
        if (fuelMap != null) {
          try {
            final fuelLog = FuelLogData.fromJson(fuelMap);
            final ab = _computeActualSectionMacros(fuelLog, 'before_run');
            final ad = _computeActualSectionMacros(fuelLog, 'during_run');
            final aa = _computeActualSectionMacros(fuelLog, 'after_run');
            actualBefore = ab;
            actualDuring = ad;
            actualAfter = aa;
            actualTotalCarbs = ab.carbs + ad.carbs + aa.carbs;
            actualTotalCalories =
                ab.estimatedCalories +
                ad.estimatedCalories +
                aa.estimatedCalories;
            if (actualTotalCalories == 0) actualTotalCalories = null;

            satisfactionRating = fuelLog.overallSatisfaction;
            nutritionRating = fuelLog.nutritionRating;
            notes = fuelLog.notes;
          } catch (e) {
            _logger.warning(
              'Failed to parse fuel log for ${a.id}',
              context: 'COACH_REPORTS',
              error: e,
            );
          }
        }
      }

      // Compute adherence for this activity
      if (hasFuelLog &&
          plannedTotalCalories != null &&
          plannedTotalCalories > 0 &&
          actualTotalCalories != null) {
        adherenceValues.add(
          (actualTotalCalories / plannedTotalCalories).clamp(0.0, 2.0),
        );
      }

      activityItems.add(
        ActivityReportItem(
          activityId: a.id,
          name: a.title,
          activityType: a.activityType,
          scheduledDate: a.scheduledDateTime,
          durationMinutes: a.durationMinutes,
          distanceMiles: a.distanceMiles,
          status: a.status,
          isCompleted: isCompleted,
          plannedBefore: plannedBefore,
          plannedDuring: plannedDuring,
          plannedAfter: plannedAfter,
          plannedTotalCarbs: plannedTotalCarbs,
          plannedTotalCalories: plannedTotalCalories,
          actualBefore: actualBefore,
          actualDuring: actualDuring,
          actualAfter: actualAfter,
          actualTotalCarbs: actualTotalCarbs,
          actualTotalCalories: actualTotalCalories,
          hasFuelLog: hasFuelLog,
          satisfactionRating: satisfactionRating,
          nutritionRating: nutritionRating,
          notes: notes,
        ),
      );
    }

    // Upcoming events (next event, no upper bound)
    final events =
        await (db.select(db.eventsTable)
              ..where(
                (t) =>
                    t.userId.equals(athleteId) &
                    t.eventDate.isBiggerOrEqualValue(today),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.eventDate)])
              ..limit(1))
            .get();

    final completed = activities
        .where((a) => a.completedAt != null || a.status == 'completed')
        .length;

    double? avgAdherence;
    if (adherenceValues.isNotEmpty) {
      avgAdherence =
          adherenceValues.reduce((a, b) => a + b) / adherenceValues.length;
    }

    return AthleteDetailReport(
      relationship: athlete,
      activitiesPlanned: activities.length,
      activitiesCompleted: completed,
      fuelLogsCount: fuelLogsCount,
      avgAdherence: avgAdherence,
      nextEventName: events.isNotEmpty ? events.first.eventName : null,
      nextEventDate: events.isNotEmpty ? events.first.eventDate : null,
      activities: activityItems,
    );
  }

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  /// Select an athlete to view their detailed report
  Future<void> selectAthlete(String relationshipId) async {
    final current = state.value;
    if (current == null) return;

    final athlete = current.overviews
        .where((o) => o.relationship.id == relationshipId)
        .firstOrNull
        ?.relationship;
    if (athlete == null) return;

    state = AsyncValue.data(
      current.copyWith(
        selectedRelationshipId: relationshipId,
        clearSelectedReport: true,
      ),
    );

    // Load detail in background, update state when ready
    state = await AsyncValue.guard(() async {
      final report = await _loadAthleteDetail(athlete, current.dateRange);
      return current.copyWith(
        selectedRelationshipId: relationshipId,
        selectedReport: report,
      );
    });
  }

  /// Go back to triage overview
  void backToOverview() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        clearSelectedRelationshipId: true,
        clearSelectedReport: true,
      ),
    );
  }

  /// Switch date range and reload
  Future<void> setDateRange(ReportsDateRange range) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadTriageOverview(range));
  }

  /// Refresh current view
  Future<void> refresh() async {
    final current = state.value;
    final range = current?.dateRange ?? const ReportsDateRange.thisWeek();

    if (current?.selectedRelationshipId != null &&
        current?.selectedReport != null) {
      // Refresh the selected athlete's detail
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final overview = await _loadTriageOverview(range);
        final report = await _loadAthleteDetail(
          current!.selectedReport!.relationship,
          range,
        );
        return overview.copyWith(
          selectedRelationshipId: current.selectedRelationshipId,
          selectedReport: report,
        );
      });
    } else {
      // Refresh triage overview
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _loadTriageOverview(range));
    }
  }

  // -------------------------------------------------------------------------
  // Nutrition parsing helpers
  // -------------------------------------------------------------------------

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse sections from nutrition plan JSON, handling both v1 and v2 formats
  Map<String, SectionMacros> _parseSections(Map<String, dynamic> planMap) {
    final result = <String, SectionMacros>{};

    // v2 format: has 'sections' array
    if (planMap['sections'] is List) {
      for (final raw in planMap['sections'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id'] as String?;
        if (id == null) continue;

        // Prefer section-level targets, fall back to summing food items
        double carbs = (raw['carbsTarget'] as num?)?.toDouble() ?? 0;
        double protein = (raw['proteinTarget'] as num?)?.toDouble() ?? 0;
        double fat = (raw['fatTarget'] as num?)?.toDouble() ?? 0;

        // If targets are zero, try summing from food items
        if (carbs == 0 && protein == 0 && fat == 0) {
          final macros = _sumFoodItemMacros(raw);
          carbs = macros.carbs.toDouble();
          protein = macros.protein.toDouble();
          fat = macros.fat.toDouble();
        }

        // Also check sub-phases for before section
        if ((raw['subPhases'] is List) && carbs == 0) {
          for (final sp in raw['subPhases'] as List) {
            if (sp is! Map<String, dynamic>) continue;
            carbs += (sp['carbsTarget'] as num?)?.toDouble() ?? 0;
            protein += (sp['proteinTarget'] as num?)?.toDouble() ?? 0;
            fat += (sp['fatTarget'] as num?)?.toDouble() ?? 0;
          }
        }

        result[id] = SectionMacros(
          carbs: carbs.round(),
          protein: protein.round(),
          fat: fat.round(),
        );
      }
    }

    // v1 edge function format: has 'before', 'during', 'after' arrays
    if (result.isEmpty) {
      for (final key in ['before', 'during', 'after']) {
        if (planMap[key] is List) {
          final sectionId = '${key}_run';
          final macros = _sumFoodListMacros(planMap[key] as List);
          result[sectionId] = macros;
        }
      }
    }

    return result;
  }

  SectionMacros _sumFoodItemMacros(Map<String, dynamic> sectionJson) {
    int carbs = 0, protein = 0, fat = 0;
    final items = sectionJson['foodItems'] as List<dynamic>?;
    if (items == null) return const SectionMacros();
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final info = item['nutritionalInfo'] as Map<String, dynamic>?;
      if (info == null) continue;
      carbs += (info['carbs'] as num?)?.toInt() ?? 0;
      protein += (info['protein'] as num?)?.toInt() ?? 0;
      fat += (info['fat'] as num?)?.toInt() ?? 0;
    }
    return SectionMacros(carbs: carbs, protein: protein, fat: fat);
  }

  SectionMacros _sumFoodListMacros(List items) {
    int carbs = 0, protein = 0, fat = 0;
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final info =
          item['nutritional_info'] as Map<String, dynamic>? ??
          item['nutritionalInfo'] as Map<String, dynamic>?;
      if (info == null) continue;
      carbs +=
          (info['carbs'] as num?)?.toInt() ??
          (info['carbs_g'] as num?)?.toInt() ??
          0;
      protein +=
          (info['protein'] as num?)?.toInt() ??
          (info['protein_g'] as num?)?.toInt() ??
          0;
      fat +=
          (info['fat'] as num?)?.toInt() ??
          (info['fat_g'] as num?)?.toInt() ??
          0;
    }
    return SectionMacros(carbs: carbs, protein: protein, fat: fat);
  }

  SectionMacros _computeActualSectionMacros(
    FuelLogData fuelLog,
    String sectionId,
  ) {
    final items = fuelLog.itemsForSection(sectionId);
    int carbs = 0, protein = 0, fat = 0, calories = 0;
    for (final item in items) {
      final info = item.actualNutritionalInfo;
      if (info == null) continue;
      carbs += info.carbs ?? 0;
      protein += info.protein ?? 0;
      fat += info.fat ?? 0;
      calories += info.calories ?? 0;
    }
    return SectionMacros(
      carbs: carbs,
      protein: protein,
      fat: fat,
      calories: calories > 0 ? calories : null,
    );
  }

  int? _extractPlannedCalories(String nutritionPlanData) {
    final map = _parseJson(nutritionPlanData);
    if (map == null) return null;
    final macro = map['macroTargets'];
    if (macro is Map<String, dynamic>) {
      return (macro['calories'] as num?)?.toInt();
    }
    // Fall back to summing sections
    final sections = _parseSections(map);
    if (sections.isEmpty) return null;
    final total = sections.values.fold<int>(
      0,
      (sum, s) => sum + s.estimatedCalories,
    );
    return total > 0 ? total : null;
  }

  int? _extractActualCalories(String fuelLogData) {
    final map = _parseJson(fuelLogData);
    if (map == null) return null;
    try {
      final fuelLog = FuelLogData.fromJson(map);
      int total = 0;
      for (final item in fuelLog.items) {
        total += item.actualNutritionalInfo?.calories ?? 0;
      }
      return total > 0 ? total : null;
    } catch (_) {
      return null;
    }
  }
}
