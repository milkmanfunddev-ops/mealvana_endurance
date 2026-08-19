// GOLDENS for the macro-dashboard components — one PNG per row of
// docs/ssot/conformance/design/macro-dashboard.goldens.yaml (the design
// analogue of a vectors file). Every golden renders from the CANONICAL MOCK
// DAY (two-workout persona: verified 8:00 swim 229 kcal, planned 5:30 run
// 1,205 kcal, snapshot 15:00, eaten 1,650, targets 4,152 / 596C / 130P /
// 138F) at token-resolved colors with the real app fonts.
//
// RULE (component specs): a golden may only be regenerated AFTER the design
// spec changes — never to make a red test pass. Regeneration commits cite
// the spec change.
//
//   flutter test test/features/macro_dashboard/macro_dashboard_goldens_test.dart \
//     --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/me_tokens.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/energy_summary_card.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/workout_card.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}

// ---------------------------------------------------------------------------
// The canonical mock day
// ---------------------------------------------------------------------------

WorkoutCardData _swim(WorkoutCardState state) => WorkoutCardData(
      activityId: 'w1',
      name: 'Swim',
      timeLabel: '8:00 AM',
      metaLabel: '2,000 yd · 40 min',
      kcal: 229,
      state: state,
      sport: 'swimming',
    );

WorkoutCardData _run(WorkoutCardState state) => WorkoutCardData(
      activityId: 'w2',
      name: 'Run',
      timeLabel: '5:30 PM',
      metaLabel: '90 min',
      kcal: 1205,
      state: state,
      sport: 'running',
    );

/// Mock-day energy numbers: burned 1,783 (resting 1,192 + movement 197 +
/// swim 229 + digestion 165), net −133 → "on track", projected 1,434.
const _energy = EnergyCardData(
  netKcal: -133,
  bandCopy: 'on track',
  eatenKcal: 1650,
  burnedKcal: 1783,
  targetKcal: 4152,
  remainingKcal: 2502,
  workoutDoneKcal: 229,
  workoutPlannedKcal: 1205,
  workoutProjectedKcal: 1434,
  workoutRows: [
    EnergyWorkoutRow(
      name: 'Swim',
      note: '8:00 AM · 2,000 yd · 40 min',
      kcal: 229,
      planned: false,
    ),
    EnergyWorkoutRow(
      name: 'Run',
      note: 'planned · 5:30 PM · 90 min',
      kcal: 1205,
      planned: true,
    ),
  ],
  carbTargetG: 596,
  proteinTargetG: 130,
  fatTargetG: 138,
  carbEatenG: 262,
  proteinEatenG: 68,
  fatEatenG: 36,
);

Widget _frame(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: MeTokens.blackberry,
        body: Center(
          child: SizedBox(
            width: 380,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFont('Sansita', [
      'assets/fonts/Sansita/Sansita-Regular.otf',
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ]);
    await _loadFont('Apercu', [
      'assets/fonts/Apercu/Apercu Pro Regular.otf',
      'assets/fonts/Apercu/Apercu Pro Medium.otf',
      'assets/fonts/Apercu/Apercu Pro Bold.otf',
    ]);
    await _loadFont('Apercu Mono', [
      'assets/fonts/Apercu/Apercu Pro Mono.otf',
    ]);
    await _loadFont('Compadre', [
      'assets/fonts/Compadre/Compadre-Demo-Regular.otf',
    ]);
    // Icons render as placeholder boxes unless MaterialIcons is loaded.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
        '/opt/homebrew/share/flutter';
    final materialIcons =
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(materialIcons).existsSync()) {
      await _loadFont('MaterialIcons', [materialIcons]);
    }
  });

  Future<void> golden(
    WidgetTester tester,
    Widget child,
    String name,
  ) async {
    await tester.pumpWidget(_frame(child));
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('workout-card goldens (one per state row)', () {
    testWidgets('workout_card_planned', (tester) async {
      await golden(
        tester,
        WorkoutCard(data: _run(WorkoutCardState.planned)),
        'workout_card_planned',
      );
    });

    testWidgets('workout_card_done_confirmed', (tester) async {
      await golden(
        tester,
        WorkoutCard(data: _swim(WorkoutCardState.doneConfirmed)),
        'workout_card_done_confirmed',
      );
    });

    testWidgets('workout_card_done_verified', (tester) async {
      await golden(
        tester,
        WorkoutCard(data: _swim(WorkoutCardState.doneVerified)),
        'workout_card_done_verified',
      );
    });

    // Regenerated 2026-08-17 (spec change: Q-D5 ruling + Q-D6/D-2 v2
    // clarification — SKIPPED = planned treatment DRAINED TO NEUTRAL, chip
    // "Skipped"), blessed from the reference rendering's previous-day view
    // (prototype @ 5a22ca8, day-16 run). Passive and active SKIPPED share
    // this one golden — the card is identical; only the trigger differs.
    testWidgets('workout_card_skipped', (tester) async {
      await golden(
        tester,
        WorkoutCard(data: _run(WorkoutCardState.skipped)),
        'workout_card_skipped',
      );
    });
  });

  group('energy-card goldens (3 faces x 2 expansion states)', () {
    for (final (face, faceName) in [
      (DashboardFilter.all, 'all'),
      (DashboardFilter.workout, 'workout'),
      (DashboardFilter.meals, 'meals'),
    ]) {
      for (final expanded in [false, true]) {
        final name =
            'energy_card_${faceName}_${expanded ? 'expanded' : 'collapsed'}';
        testWidgets(name, (tester) async {
          await golden(
            tester,
            EnergySummaryCard(
              face: face,
              expanded: expanded,
              data: _energy,
              onToggleExpanded: () {},
            ),
            name,
          );
        });
      }
    }
  });
}
