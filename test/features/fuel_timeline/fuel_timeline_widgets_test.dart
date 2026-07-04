import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/day_energy_summary.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/fuel_timeline_filter.dart';
import 'package:mealvana_endurance/features/fuel_timeline/domain/timeline_node.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/energy_dashboard_card.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/fuel_filter_row.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/timeline_node_tile.dart';
import 'package:mealvana_endurance/features/fuel_timeline/presentation/widgets/weekly_fuel_chart.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';

void main() {
  final date = DateTime(2026, 6, 17);

  // EnergyDashboardCard and TimelineNodeTile read unitSystemProvider (both
  // are ConsumerWidgets) - pin it to imperial so distance/speed assertions
  // below (written against mi/mph) stay deterministic regardless of the
  // provider's real DB-backed default.
  Widget wrap(Widget child, {double width = 360}) => ProviderScope(
        overrides: [
          unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      );

  MealLog meal() => MealLog(
        id: 'm1',
        userId: 'u',
        logDate: '2026-06-17',
        slot: MealSlot.breakfast,
        name: 'Everything Bagel',
        source: MealLogSource.manual,
        components: const [],
        calories: 574,
        carbsG: 58,
        proteinG: 30,
        fatG: 25,
        eatenAt: DateTime(2026, 6, 17, 7, 30),
        createdAt: date,
        updatedAt: date,
      );

  Activity ride() => Activity(
        id: 'a1',
        userId: 'u',
        activityType: ActivityType.cycling,
        title: '25 mi Ride',
        scheduledDateTime: DateTime(2026, 6, 17, 16, 15),
        distanceMiles: 25,
        cyclingSpeedMph: 15,
        durationMinutes: 100,
        createdAt: date,
        updatedAt: date,
      );

  Activity run() => Activity(
        id: 'a2',
        userId: 'u',
        activityType: ActivityType.running,
        title: '5 mi Run',
        scheduledDateTime: DateTime(2026, 6, 17, 6, 30),
        distanceMiles: 5,
        durationMinutes: 40,
        createdAt: date,
        updatedAt: date,
      );

  DayEnergySummary summary({
    DateTime? at,
    DateTime? selected,
    ConsumedTotals consumed =
        const ConsumedTotals(calories: 574, carbsG: 58, proteinG: 30, fatG: 25),
    double workoutBurned = 0,
  }) =>
      DayEnergySummary.compute(
        selectedDate: selected ?? date,
        now: at ?? DateTime(2026, 6, 17, 20),
        targets: DailyMacroTargets(
          id: 't',
          userId: 'u',
          targetDate: date,
          carbG: 300,
          protG: 140,
          fatG: 75,
          tdee: 1911,
          rmr: 1091,
          sessionKcal: 502,
          neatKcal: 300,
          mode: 'prospective',
          createdAt: date,
          updatedAt: date,
        ),
        consumed: consumed,
        workoutBurnedKcal: workoutBurned,
      );

  // ── TimelineNodeTile ───────────────────────────────────────────────────────
  group('TimelineNodeTile', () {
    testWidgets('meal card shows name + macro line when tracking on',
        (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: true,
        trackingOn: true,
      )));
      expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
      expect(find.text('7:30 AM'), findsOneWidget); // time rail
      // macro line is one rich Text containing the kcal + macro tokens.
      expect(find.textContaining('574 kcal'), findsOneWidget);
    });

    testWidgets('tracking off hides the macro line', (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: true,
        trackingOn: false,
      )));
      expect(find.text('EVERYTHING BAGEL'), findsOneWidget);
      expect(find.textContaining('574 kcal'), findsNothing);
    });

    testWidgets('timeline closed hides the time label', (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: false,
        trackingOn: true,
      )));
      expect(find.text('7:30 AM'), findsNothing);
    });

    testWidgets('swipe left→right fires onRemove (swipe to delete)',
        (tester) async {
      var removed = false;
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: true,
        trackingOn: true,
        onRemove: () => removed = true,
        onSwap: () {},
      )));
      await tester.drag(find.byType(Dismissible), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('swipe right→left fires onSwap (swipe to swap)',
        (tester) async {
      var swapped = false;
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: true,
        trackingOn: true,
        onRemove: () {},
        onSwap: () => swapped = true,
      )));
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(swapped, isTrue);
    });

    testWidgets('meal tile has no overflow "…" icon', (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: MealNode(meal()),
        timelineOpen: true,
        trackingOn: true,
        onTap: () {},
      )));
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('workout card shows title + fuel hint, fires onTap',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: WorkoutNode(ride()),
        timelineOpen: true,
        trackingOn: true,
        onTap: () => tapped = true,
      )));
      expect(find.text('25 MI RIDE'), findsOneWidget);
      expect(find.textContaining('Recovery fuel'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('25 MI RIDE'));
      expect(tapped, isTrue);
    });

    testWidgets('workout card icon matches the activity type (not always '
        'cycling)', (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: WorkoutNode(run()),
        timelineOpen: true,
        trackingOn: true,
      )));
      expect(find.byIcon(Icons.directions_run), findsOneWidget);
      expect(find.byIcon(Icons.directions_bike), findsNothing);
    });

    testWidgets('workout swipe left→right fires onRemove', (tester) async {
      var removed = false;
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: WorkoutNode(ride()),
        timelineOpen: true,
        trackingOn: true,
        onRemove: () => removed = true,
        onSwap: () {},
      )));
      await tester.drag(find.byType(Dismissible), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });

    testWidgets('workout swipe right→left fires onSwap', (tester) async {
      var swapped = false;
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: WorkoutNode(ride()),
        timelineOpen: true,
        trackingOn: true,
        onRemove: () {},
        onSwap: () => swapped = true,
      )));
      await tester.drag(find.byType(Dismissible), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(swapped, isTrue);
    });

    testWidgets('workout card with no swipe callbacks has no Dismissible',
        (tester) async {
      await tester.pumpWidget(wrap(TimelineNodeTile(
        node: WorkoutNode(ride()),
        timelineOpen: true,
        trackingOn: true,
        onTap: () {},
      )));
      expect(find.byType(Dismissible), findsNothing);
    });
  });

  // ── EnergyDashboardCard ─────────────────────────────────────────────────────
  group('EnergyDashboardCard', () {
    Widget card(FuelTimelineFilter filter, bool expanded,
            {VoidCallback? onToggle, VoidCallback? onOpen}) =>
        wrap(EnergyDashboardCard(
          filter: filter,
          summary: summary(),
          workouts: [WorkoutNode(ride())],
          expanded: expanded,
          onToggle: onToggle ?? () {},
          onOpenBreakdown: onOpen ?? () {},
        ));

    testWidgets('All collapsed shows Intake + Burned', (tester) async {
      await tester.pumpWidget(card(FuelTimelineFilter.all, false));
      expect(find.text('INTAKE'), findsOneWidget);
      expect(find.text('BURNED'), findsOneWidget);
    });

    testWidgets('All expanded shows Energy Balance + Net + breakdown',
        (tester) async {
      await tester.pumpWidget(card(FuelTimelineFilter.all, true));
      expect(find.text('ENERGY BALANCE'), findsOneWidget);
      expect(find.text('Net intake'), findsOneWidget);
      expect(find.text('Full Breakdown'), findsOneWidget);
    });

    testWidgets('Meals collapsed shows Daily budget', (tester) async {
      await tester.pumpWidget(card(FuelTimelineFilter.meals, false));
      expect(find.text('DAILY BUDGET'), findsOneWidget);
    });

    testWidgets('Meals expanded shows macro bars', (tester) async {
      await tester.pumpWidget(card(FuelTimelineFilter.meals, true));
      expect(find.text('INTAKE TODAY'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('Workout expanded shows Active Energy + the ride row',
        (tester) async {
      await tester.pumpWidget(card(FuelTimelineFilter.workout, true));
      expect(find.text('ACTIVE ENERGY'), findsOneWidget);
      expect(find.text('25 MI RIDE'), findsOneWidget);
    });

    testWidgets('chevron + Full Breakdown fire callbacks', (tester) async {
      var toggled = false, opened = false;
      await tester.pumpWidget(card(FuelTimelineFilter.all, true,
          onToggle: () => toggled = true, onOpen: () => opened = true));
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.tap(find.text('Full Breakdown'));
      expect(toggled, isTrue);
      expect(opened, isTrue);
    });

    testWidgets('future day hides the Burned stat (collapsed All)',
        (tester) async {
      await tester.pumpWidget(wrap(EnergyDashboardCard(
        filter: FuelTimelineFilter.all,
        summary: summary(
            selected: DateTime(2026, 6, 18), at: DateTime(2026, 6, 17, 12)),
        workouts: const [],
        expanded: false,
        onToggle: () {},
        onOpenBreakdown: () {},
      )));
      expect(find.text('INTAKE'), findsOneWidget);
      expect(find.text('BURNED'), findsNothing);
    });
  });

  // ── FuelFilterRow ───────────────────────────────────────────────────────────
  group('FuelFilterRow', () {
    testWidgets('tapping a segment + toggles fire callbacks', (tester) async {
      FuelTimelineFilter? picked;
      var tracking = false, timeline = false;
      await tester.pumpWidget(wrap(FuelFilterRow(
        filter: FuelTimelineFilter.all,
        trackingOn: true,
        timelineOpen: true,
        onPickFilter: (f) => picked = f,
        onToggleTracking: () => tracking = true,
        onToggleTimeline: () => timeline = true,
      )));

      await tester.tap(find.text('Workout'));
      expect(picked, FuelTimelineFilter.workout);

      await tester.tap(find.byIcon(Icons.show_chart));
      expect(tracking, isTrue);

      await tester.tap(find.byIcon(Icons.schedule));
      expect(timeline, isTrue);
    });
  });

  // ── WeeklyFuelChart ─────────────────────────────────────────────────────────
  group('WeeklyFuelChart', () {
    testWidgets('renders legend and survives null days', (tester) async {
      final week = <DailyMacroTargets?>[
        for (var i = 0; i < 7; i++)
          i == 3
              ? null
              : DailyMacroTargets(
                  id: 't$i',
                  userId: 'u',
                  targetDate: date.add(Duration(days: i)),
                  carbG: 200 + i * 20,
                  protG: 140,
                  fatG: 70,
                  tdee: 2400,
                  rmr: 1100,
                  sessionKcal: 300,
                  neatKcal: 300,
                  mode: 'prospective',
                  createdAt: date,
                  updatedAt: date,
                ),
      ];
      await tester.pumpWidget(wrap(WeeklyFuelChart(week: week), width: 340));
      expect(find.text('Cal'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('all-null week renders without crashing', (tester) async {
      await tester.pumpWidget(wrap(
          WeeklyFuelChart(week: List<DailyMacroTargets?>.filled(7, null)),
          width: 340));
      expect(find.byType(WeeklyFuelChart), findsOneWidget);
    });
  });
}
