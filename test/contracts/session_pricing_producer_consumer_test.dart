import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_session_legs.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/macro_dashboard/application/dashboard_assembler.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/nutrition_plan/application/daily_baseline_calculator.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/domain/session_input_resolver.dart';

import '../fixtures/final_surge_fixtures.dart';

/// **The producer→consumer contract tier** — first instance.
///
/// Every other suite in this repo is fed hand-authored fixtures, and the
/// fixtures on the two sides of this seam encoded contradictory assumptions:
/// `final_surge_transformer_test.dart` asserts `durationMinutes, isNull` ten
/// times over (with distance and pace set — the deliberate production shape),
/// while every consumer fixture populated duration. No test imported both, so
/// both halves passed forever and the macro dashboard shipped priced at a flat
/// 60 minutes for every distance-prescribed session — a 3 mi, a 6.2 mi and a
/// 15 mi run all reading 510 kcal, ~47% low on the long run, contradicting the
/// macro targets on the same screen by 649 kcal on a real athlete's account.
///
/// Full analysis + why 323 test files stayed green:
/// `ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`.
/// Ratification of this tier as a data-SSOT family is queued as `qa/PLAN.md`
/// Phase 5 / `qa/intake/2026-08-22-data-ssot-producer-shapes.md`.
///
/// The rule these tests encode: **rows come from the real producer, never from
/// a hand-authored literal.** That is what makes a deliberate NULL impossible
/// to assume away.
/// The ruled zones-absent IF — derived from the shared default distribution,
/// never a literal, so this suite tracks the resolver instead of shadowing it.
final double _zonelessIf = DailyBaselineCalculator.zoneDistributionToIf(
  pctConversational: SessionInputResolver.defaultZ1Z2Pct / 100,
  pctTempo: SessionInputResolver.defaultZ3Z4Pct / 100,
  pctAllout: SessionInputResolver.defaultZ5Pct / 100,
);

void main() {
  const transformer = FinalSurgeTransformer();
  const assembler = MacroDashboardAssembler();
  final day = DateTime(2026, 8, 29);
  final now = DateTime(2026, 8, 29, 12, 0);
  const weightKg = 47.6;

  /// A distance-prescribed Final Surge workout — the shape the transformer
  /// deliberately writes with a NULL duration. Built by mutating a REAL
  /// captured payload rather than hand-rolling one: an invented map is just
  /// another hand-authored fixture, which is the habit this tier exists to
  /// break.
  Map<String, dynamic> fsRun(double miles, String pace) =>
      Map<String, dynamic>.from(FinalSurgeFixtures.runningWorkoutComplete)
        ..['WorkoutDate'] = '2026-08-29T00:00:00'
        ..['PlannedDistance'] = miles
        ..['PlannedDistanceType'] = 'mi'
        ..['PlannedPace'] = pace
        ..['PlannedPaceType'] = 'min/mi'
        ..['PlannedTime'] = null
        ..['ActualTime'] = null;

  Activity produce(Map<String, dynamic> workout) {
    final result = transformer.transform(workout, 'u1');
    expect(result, isNotNull, reason: 'fixture must transform');
    return result!.activity;
  }

  group('the producer really does write the shape we think it does', () {
    test('a distance+pace run arrives with NULL duration and a live distance',
        () {
      final a = produce(fsRun(15.0, '9:10'));

      expect(a.durationMinutes, isNull,
          reason: 'the transformer deliberately leaves duration to consumers');
      expect(a.distanceMiles, closeTo(15.0, 0.001));
      expect(a.paceTargetMinutesPerMile, isNotNull,
          reason: 'the pace it expects consumers to derive minutes from');
      // Precondition for the engine-agreement test below, which pins IF at the
      // ruled zones-absent default on BOTH sides (RULED 2026-08-22: display
      // adopts the engine's 70/20/10 through the one RMS derivation). If a
      // future fixture starts carrying zones, that test would compare two
      // different IFs and could pass for the wrong reason — so assert the
      // precondition here rather than let it drift silently.
      expect(a.intensityDistribution, isNull,
          reason: 'this fixture must stay zoneless for the IF pin to hold');
    });
  });

  group('every consumer resolves that shape the same way', () {
    test('the resolver derives minutes from distance x prescribed pace', () {
      final a = produce(fsRun(15.0, '9:10'));

      final minutes = SessionInputResolver.durationMinutes(
        activityType: a.activityType.name,
        explicitMinutes: a.durationMinutes,
        distanceMiles: a.distanceMiles,
        paceTargetMinutesPerMile: a.paceTargetMinutesPerMile,
      );

      expect(minutes, greaterThan(120),
          reason: '15 mi at ~9:10/mi is well over two hours, never 60 min');
      expect(minutes, isNot(SessionInputResolver.fallbackMinutes),
          reason: 'the flat fallback is exactly the bug');
    });

    test(
        'BUG_CHECK: a 3 mi and a 15 mi run at the same pace DO NOT price alike',
        () {
      double priced(double miles) {
        final a = produce(fsRun(miles, '9:10'));
        final minutes = SessionInputResolver.durationMinutes(
          activityType: a.activityType.name,
          explicitMinutes: a.durationMinutes,
          distanceMiles: a.distanceMiles,
          paceTargetMinutesPerMile: a.paceTargetMinutesPerMile,
        );
        return DailyBaselineCalculator.sessionCost(
          sport: SessionInputResolver.displaySport(a.activityType.name),
          durationHr: minutes / 60.0,
          intensityFactor: _zonelessIf,
          weightKg: weightKg,
        );
      }

      final short = priced(3.0);
      final long = priced(15.0);

      // The shipped bug made these exactly equal (510 kcal each).
      expect(long, greaterThan(short * 4),
          reason: 'five times the distance at one pace is ~5x the work');
    });
  });

  group('the dashboard agrees with the engine that priced the targets', () {
    test(
        'displayed session kcal reconciles with targets.sessionKcal — the '
        'cross-check that makes a silent divergence impossible', () {
      final a = produce(fsRun(15.0, '9:10'));

      // What the ENGINE would have been sent for this row, and therefore what
      // it priced the athlete's macros with.
      final engineMinutes = SessionInputResolver.durationMinutes(
        activityType: a.activityType.name,
        explicitMinutes: a.durationMinutes,
        distanceMiles: a.distanceMiles,
        paceTargetMinutesPerMile: a.paceTargetMinutesPerMile,
      );
      final engineSessionKcal = DailyBaselineCalculator.sessionCost(
        sport: SessionInputResolver.engineSport(a.activityType.name),
        durationHr: engineMinutes / 60.0,
        intensityFactor: _zonelessIf,
        weightKg: weightKg,
      );

      final targets = DailyMacroTargets(
        id: 't1',
        userId: 'u1',
        targetDate: day,
        carbG: 447,
        protG: 85,
        fatG: 101,
        tdee: 3037,
        rmr: 1064,
        sessionKcal: engineSessionKcal,
        neatKcal: 275,
        tefKcal: 304,
        mode: 'prospective',
        createdAt: day,
        updatedAt: day,
      );

      final data = assembler.assemble(
        selectedDate: day,
        now: now,
        activities: [a],
        meals: const [],
        targets: targets,
        consumed: const ConsumedTotals(),
        trackingOn: true,
        profileWeightKg: weightKg,
      );

      final displayed = data.nodes
          .where((n) => n.isWorkout)
          .map((n) => n.workout!.kcal ?? 0)
          .fold<double>(0, (a, b) => a + b);

      expect(displayed, closeTo(targets.sessionKcal, 1.0),
          reason: 'the dashboard must explain the targets beside it, '
              'not hold an independent opinion about the same session');
    });
  });

  group('a brick prices as the sum of its legs — and both sides agree', () {
    // The wire shape activity_mapper persists (snake_case), not the Dart
    // constructors: run 65 → bike 100 → run 144, the brick from
    // ops/data/bug-reports/2026-09-04-brick-priced-as-one-conservative-session.md.
    // Until 2026-09-04 the ENGINE priced this as one 309-min running session
    // while the DISPLAY priced it as one 309-min conservative-rate session —
    // both wrong, and visibly contradicting each other (~2×) on one screen.
    // INTERIM per-leg decomposition pending
    // qa/intake/2026-09-04-brick-per-leg-pricing-ratification.md.
    final metadata = BrickMetadata.fromJson({
      'segment_order': ['running', 'cycling', 'running'],
      'segments': [
        {'sport': 'running', 'order': 1, 'duration_minutes': 65, 'intensity': 'moderate'},
        {'sport': 'cycling', 'order': 2, 'duration_minutes': 100, 'intensity': 'moderate'},
        {'sport': 'running', 'order': 3, 'duration_minutes': 144, 'intensity': 'moderate'},
      ],
      'created_from_existing': false,
      'total_duration_minutes': 309,
    });

    final brick = Activity(
      id: 'brick1',
      userId: 'u1',
      activityType: ActivityType.brick,
      title: 'RUN/BIKE/RUN',
      scheduledDateTime: DateTime(day.year, day.month, day.day, 6),
      durationMinutes: 309,
      brickMetadata: metadata,
      createdAt: day,
      updatedAt: day,
    );

    // What the ENGINE is now fed (one session per leg, each at its own
    // sport's ratified rate — see brick_session_expansion_test.dart for the
    // wire payload itself) and therefore what it prices the targets with.
    double engineSum() {
      var sum = 0.0;
      for (final leg in metadata.sessionLegs) {
        sum += DailyBaselineCalculator.sessionCost(
          sport: leg.sport,
          durationHr: leg.durationMinutes / 60.0,
          intensityFactor: _zonelessIf,
          weightKg: weightKg,
        );
      }
      return sum;
    }

    test('the dashboard shows the per-leg sum and reconciles with the '
        'targets beside it', () {
      final targets = DailyMacroTargets(
        id: 't1',
        userId: 'u1',
        targetDate: day,
        carbG: 447,
        protG: 85,
        fatG: 101,
        tdee: 3037,
        rmr: 1064,
        sessionKcal: engineSum(),
        neatKcal: 275,
        tefKcal: 304,
        mode: 'prospective',
        createdAt: day,
        updatedAt: day,
      );

      final data = assembler.assemble(
        selectedDate: day,
        now: now,
        activities: [brick],
        meals: const [],
        targets: targets,
        consumed: const ConsumedTotals(),
        trackingOn: true,
        profileWeightKg: weightKg,
      );

      final displayed = data.nodes
          .where((n) => n.isWorkout)
          .map((n) => n.workout!.kcal ?? 0)
          .fold<double>(0, (a, b) => a + b);

      expect(displayed, closeTo(targets.sessionKcal, 1.0),
          reason: 'the brick must price identically on both sides');

      // Direction pin: the bike leg at the cycling rate lands strictly
      // between the two old wrong answers — above the conservative-rate
      // whole (the shipped 1,980-kcal face) and below running-rate-for-
      // everything (what the engine used to feed the targets).
      final conservativeWhole = DailyBaselineCalculator.sessionCost(
        sport: 'brick',
        durationHr: 309 / 60.0,
        intensityFactor: _zonelessIf,
        weightKg: weightKg,
      );
      final runningWhole = DailyBaselineCalculator.sessionCost(
        sport: 'running',
        durationHr: 309 / 60.0,
        intensityFactor: _zonelessIf,
        weightKg: weightKg,
      );
      expect(displayed, greaterThan(conservativeWhole));
      expect(displayed, lessThan(runningWhole));
    });

    test('a brick with NO segment metadata keeps the interim conservative '
        'fallback instead of inventing legs', () {
      final bare = Activity(
        id: 'brick2',
        userId: 'u1',
        activityType: ActivityType.brick,
        title: 'BRICK',
        scheduledDateTime: DateTime(day.year, day.month, day.day, 6),
        durationMinutes: 90,
        createdAt: day,
        updatedAt: day,
      );
      final data = assembler.assemble(
        selectedDate: day,
        now: now,
        activities: [bare],
        meals: const [],
        targets: null,
        consumed: const ConsumedTotals(),
        trackingOn: true,
        profileWeightKg: weightKg,
      );
      final kcal =
          data.nodes.where((n) => n.isWorkout).single.workout!.kcal;
      expect(
        kcal,
        closeTo(
          DailyBaselineCalculator.sessionCost(
            sport: 'brick',
            durationHr: 1.5,
            intensityFactor: _zonelessIf,
            weightKg: weightKg,
          ),
          0.001,
        ),
      );
    });
  });

  group('engine and display sport mappings diverge ONLY where ruled', () {
    test('they agree everywhere except the composite types', () {
      const composite = {'triathlon', 'duathlon', 'multisport', 'brick'};

      for (final type in ActivityType.values) {
        final name = type.name;
        if (composite.contains(name)) {
          expect(SessionInputResolver.displaySport(name), name,
              reason: '$name stays on the interim conservative rate pending '
                  'qa/intake/2026-08-20-session-cost-unknown-activity-types.md '
                  '(for a BRICK this is now only the no-metadata fallback — '
                  'a brick with segments prices per-leg on both sides, see '
                  'the brick group above)');
        } else {
          expect(
            SessionInputResolver.displaySport(name),
            SessionInputResolver.engineSport(name),
            reason: '$name must price identically on both sides',
          );
        }
      }
    });

    test('`other` maps to strength on BOTH sides — engine and display', () {
      expect(SessionInputResolver.engineSport('other'), 'strength');
      expect(SessionInputResolver.displaySport('other'), 'strength');
      expect(
        SessionInputResolver.durationMinutes(activityType: 'other'),
        SessionInputResolver.fallbackOtherMinutes,
        reason: 'a mobility routine is 30 min by convention, not 60',
      );
    });
  });
}
