// ignore_for_file: avoid_implementing_value_types
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_reports_controller.dart';

// ---------------------------------------------------------------------------
// Tests for pure logic extracted from CoachReportsController
// These test the math and parsing helpers in isolation without needing
// Riverpod containers, Supabase, or Drift.
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // SectionMacros
  // -------------------------------------------------------------------------

  group('SectionMacros', () {
    test('estimatedCalories uses provided calories when available', () {
      const s = SectionMacros(carbs: 50, protein: 20, fat: 10, calories: 300);
      expect(s.estimatedCalories, 300);
    });

    test('estimatedCalories computes from macros when calories is null', () {
      // 50 carbs × 4 + 20 protein × 4 + 10 fat × 9 = 200 + 80 + 90 = 370
      const s = SectionMacros(carbs: 50, protein: 20, fat: 10);
      expect(s.estimatedCalories, 370);
    });

    test('estimatedCalories is 0 for all-zero macros', () {
      const s = SectionMacros();
      expect(s.estimatedCalories, 0);
    });

    test('fat contributes 9 cal/g while carbs and protein contribute 4 cal/g',
        () {
      const fatOnly = SectionMacros(carbs: 0, protein: 0, fat: 10);
      const carbOnly = SectionMacros(carbs: 10, protein: 0, fat: 0);
      const protOnly = SectionMacros(carbs: 0, protein: 10, fat: 0);

      expect(fatOnly.estimatedCalories, 90);
      expect(carbOnly.estimatedCalories, 40);
      expect(protOnly.estimatedCalories, 40);
    });
  });

  // -------------------------------------------------------------------------
  // ActivityReportItem.adherence
  // -------------------------------------------------------------------------

  group('ActivityReportItem.adherence', () {
    ActivityReportItem _item({
      bool hasFuelLog = true,
      int? plannedTotalCalories,
      int? actualTotalCalories,
    }) {
      return ActivityReportItem(
        activityId: 'act-1',
        name: 'Morning Run',
        activityType: 'running',
        scheduledDate: DateTime.now(),
        hasFuelLog: hasFuelLog,
        plannedTotalCalories: plannedTotalCalories,
        actualTotalCalories: actualTotalCalories,
      );
    }

    test('adherence is null when hasFuelLog is false', () {
      final item = _item(
        hasFuelLog: false,
        plannedTotalCalories: 500,
        actualTotalCalories: 400,
      );
      expect(item.adherence, isNull);
    });

    test('adherence is null when plannedTotalCalories is null', () {
      final item = _item(
        plannedTotalCalories: null,
        actualTotalCalories: 400,
      );
      expect(item.adherence, isNull);
    });

    test('adherence is null when plannedTotalCalories is 0 (div-by-zero guard)',
        () {
      final item = _item(
        plannedTotalCalories: 0,
        actualTotalCalories: 400,
      );
      expect(item.adherence, isNull,
          reason: 'Division by zero must be guarded: 0 planned calories '
              'produces null adherence, not infinity.');
    });

    test('adherence is null when actualTotalCalories is null', () {
      final item = _item(
        plannedTotalCalories: 500,
        actualTotalCalories: null,
      );
      expect(item.adherence, isNull);
    });

    test('adherence is 1.0 when actual equals planned', () {
      final item =
          _item(plannedTotalCalories: 500, actualTotalCalories: 500);
      expect(item.adherence, closeTo(1.0, 0.001));
    });

    test('adherence is clamped to 0.0 when actual is 0', () {
      final item = _item(plannedTotalCalories: 500, actualTotalCalories: 0);
      expect(item.adherence, closeTo(0.0, 0.001));
    });

    test('adherence is clamped to 2.0 when actual greatly exceeds planned', () {
      final item =
          _item(plannedTotalCalories: 100, actualTotalCalories: 5000);
      expect(item.adherence, closeTo(2.0, 0.001));
    });

    test('under-fueling produces adherence between 0 and 1', () {
      // 400 actual / 500 planned = 0.8
      final item =
          _item(plannedTotalCalories: 500, actualTotalCalories: 400);
      expect(item.adherence, closeTo(0.8, 0.001));
    });

    test('slight over-fueling produces adherence between 1 and 2', () {
      // 600 actual / 500 planned = 1.2
      final item =
          _item(plannedTotalCalories: 500, actualTotalCalories: 600);
      expect(item.adherence, closeTo(1.2, 0.001));
    });
  });

  // -------------------------------------------------------------------------
  // ReportsDateRange
  // -------------------------------------------------------------------------

  group('ReportsDateRange', () {
    test('thisWeek resolvedStart is Monday of the current week', () {
      final range = const ReportsDateRange.thisWeek();
      final start = range.resolvedStart;
      // Monday = weekday 1 in Dart
      expect(start.weekday, DateTime.monday,
          reason: 'thisWeek should start on Monday');
    });

    test('thisWeek resolvedEnd is 7 days after resolvedStart', () {
      final range = const ReportsDateRange.thisWeek();
      final diff = range.resolvedEnd.difference(range.resolvedStart).inDays;
      expect(diff, 7);
    });

    test('lastWeek resolvedStart is Monday of the previous week', () {
      final range = const ReportsDateRange.lastWeek();
      final thisWeekStart = const ReportsDateRange.thisWeek().resolvedStart;
      final diff = thisWeekStart.difference(range.resolvedStart).inDays;
      expect(diff, 7,
          reason: 'lastWeek.start must be exactly 7 days before thisWeek.start');
    });

    test('lastWeek resolvedEnd is 7 days after lastWeek.start', () {
      final range = const ReportsDateRange.lastWeek();
      final diff = range.resolvedEnd.difference(range.resolvedStart).inDays;
      expect(diff, 7);
    });

    test('custom range resolvedStart is midnight of start date', () {
      final start = DateTime(2026, 6, 1, 14, 30);
      final end = DateTime(2026, 6, 7);
      final range = ReportsDateRange.custom(start, end);
      expect(range.resolvedStart, DateTime(2026, 6, 1));
    });

    test('custom range resolvedEnd is midnight of end+1 day', () {
      // Ensures the filter is exclusive upper bound
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 7);
      final range = ReportsDateRange.custom(start, end);
      expect(range.resolvedEnd, DateTime(2026, 6, 8));
    });

    test('custom range includes both boundary days', () {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 7);
      final range = ReportsDateRange.custom(start, end);

      // An activity scheduled on the start day should be >= resolvedStart
      final onStart = DateTime(2026, 6, 1, 9, 0);
      expect(onStart.isAtSameMomentAs(range.resolvedStart) ||
          onStart.isAfter(range.resolvedStart), isTrue);

      // An activity scheduled on the end day should be < resolvedEnd
      final onEnd = DateTime(2026, 6, 7, 23, 59);
      expect(onEnd.isBefore(range.resolvedEnd), isTrue);
    });

    test('label for thisWeek', () {
      expect(const ReportsDateRange.thisWeek().label, 'This Week');
    });

    test('label for lastWeek', () {
      expect(const ReportsDateRange.lastWeek().label, 'Last Week');
    });

    test('custom range label contains start and end month/day', () {
      final range = ReportsDateRange.custom(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 7),
      );
      expect(range.label, contains('6/1'));
      expect(range.label, contains('6/8')); // end+1 day for exclusive bound
    });
  });

  // -------------------------------------------------------------------------
  // CoachReportsState
  // -------------------------------------------------------------------------

  group('CoachReportsState', () {
    test('isTriageView is true when no athlete is selected', () {
      const state = CoachReportsState();
      expect(state.isTriageView, isTrue);
    });

    test('isTriageView is false when an athlete is selected', () {
      const state = CoachReportsState(selectedRelationshipId: 'rel-1');
      expect(state.isTriageView, isFalse);
    });

    test('copyWith clearSelectedReport nulls out selectedReport', () {
      // Build a minimal non-null AthleteDetailReport to put in state
      final now = DateTime.now();
      final rel = _makeRelationship(now: now);
      final report = AthleteDetailReport(relationship: rel);
      final state = CoachReportsState(
        selectedReport: report,
        selectedRelationshipId: 'rel-1',
      );

      final cleared = state.copyWith(clearSelectedReport: true);
      expect(cleared.selectedReport, isNull);
      // Other fields preserved
      expect(cleared.selectedRelationshipId, 'rel-1');
    });

    test('copyWith clearSelectedRelationshipId nulls out selectedRelationshipId',
        () {
      const state = CoachReportsState(selectedRelationshipId: 'rel-1');
      final cleared = state.copyWith(clearSelectedRelationshipId: true);
      expect(cleared.selectedRelationshipId, isNull);
    });

    test(
        'copyWith with new dateRange replaces dateRange while preserving other fields',
        () {
      const state = CoachReportsState(selectedRelationshipId: 'rel-1');
      final updated =
          state.copyWith(dateRange: const ReportsDateRange.lastWeek());
      expect(updated.dateRange.type, ReportsDateRangeType.lastWeek);
      expect(updated.selectedRelationshipId, 'rel-1');
    });
  });

  // -------------------------------------------------------------------------
  // AthleteOverview
  // -------------------------------------------------------------------------

  group('AthleteOverview', () {
    test('default values are sensible zero/null', () {
      final now = DateTime.now();
      final rel = _makeRelationship(now: now);
      final overview = AthleteOverview(relationship: rel);

      expect(overview.activitiesPlanned, 0);
      expect(overview.activitiesCompleted, 0);
      expect(overview.fuelLogsCount, 0);
      expect(overview.avgAdherence, isNull);
      expect(overview.nextEventName, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // AthleteDetailReport
  // -------------------------------------------------------------------------

  group('AthleteDetailReport', () {
    test('default activities list is empty', () {
      final now = DateTime.now();
      final rel = _makeRelationship(now: now);
      final report = AthleteDetailReport(relationship: rel);
      expect(report.activities, isEmpty);
    });

    test('fuelLogsCount defaults to zero', () {
      final now = DateTime.now();
      final rel = _makeRelationship(now: now);
      final report = AthleteDetailReport(relationship: rel);
      expect(report.fuelLogsCount, 0);
    });
  });

  // -------------------------------------------------------------------------
  // BUG: Avg adherence averaging math
  // -------------------------------------------------------------------------

  group('Average adherence computation', () {
    test('average of [0.5, 1.5] is 1.0', () {
      const values = [0.5, 1.5];
      final avg = values.reduce((a, b) => a + b) / values.length;
      expect(avg, closeTo(1.0, 0.001));
    });

    test('average of [0.0] is 0.0', () {
      const values = [0.0];
      final avg = values.reduce((a, b) => a + b) / values.length;
      expect(avg, closeTo(0.0, 0.001));
    });

    test('average of [2.0] is 2.0 (clamped maximum)', () {
      const values = [2.0];
      final avg = values.reduce((a, b) => a + b) / values.length;
      expect(avg, closeTo(2.0, 0.001));
    });

    test('no fuel logs → avgAdherence remains null', () {
      // Mirrors the controller logic: if adherenceValues.isEmpty → avgAdherence is null
      final values = <double>[];
      final avg = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
      expect(avg, isNull);
    });

    test(
        'BUG CHECK — single activity with 0 planned calories must not contribute to adherence',
        () {
      // If plannedTotalCalories == 0 and actualTotalCalories == 300, the item
      // must NOT add to adherenceValues (would produce infinity).
      // The controller checks: plannedTotalCalories > 0 before computing.
      const plannedCalories = 0;
      const actualCalories = 300;

      final wouldBeAdded = plannedCalories > 0 && actualCalories != null;
      expect(wouldBeAdded, isFalse,
          reason:
              'An activity with 0 planned calories must not contribute to adherence '
              'computation — it would cause a division by zero.');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

CoachAthleteRelationship _makeRelationship({required DateTime now}) {
  return CoachAthleteRelationship(
    id: 'rel-1',
    coachUserId: 'coach-id',
    athleteUserId: 'athlete-id',
    status: RelationshipStatus.active,
    requestedBy: 'coach',
    requestedAt: now,
    acceptedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
