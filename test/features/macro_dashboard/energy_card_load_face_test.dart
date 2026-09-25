// L1 goldens + L2 rows for the energy card's LOAD face
// (energy-card.md §LOAD-face amendment, Q-D9 form; carb-loading@v1 G5).
//
// Golden set (named in the amendment): collapsed AND expanded ×
// today / future / past, plus the loaded flip — rendered at token-resolved
// colors with real brand fonts. The strings in the fixtures are the copy
// register's, verbatim (their derivation is pinned in
// carb_dashboard_assembler_test; the vectors pin the math).
//
// Regenerate with:
//   flutter test test/features/macro_dashboard/energy_card_load_face_test.dart --update-goldens
// RULE: a golden may only be regenerated AFTER the design spec changes —
// never to make a red test pass; regeneration commits cite the spec change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_pace_engine.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/carb_dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/widgets/energy_summary_card.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../home_shell/home_shell_test_fonts.dart';

CarbLoadFaceData face({
  String label = 'CARB LOAD · DAY 2 OF 3',
  String main = '31 g',
  String sub = 'behind pace',
  bool word = false,
  double fill = 0.5423,
  double? tick = 0.5993,
  bool loaded = false,
  CarbDayRel rel = CarbDayRel.today,
  String eatenOfTarget = '295 of 544 g',
  String toGo = '249 g to go',
  String? byNow = 'pace 326 g by now',
}) => CarbLoadFaceData(
  labelLine: label,
  paceMainStr: main,
  paceSubStr: sub,
  paceMainIsWord: word,
  fillFrac: fill,
  tickFrac: tick,
  tickHidden: tick == null,
  loaded: loaded,
  dayRel: rel,
  eatenOfTargetStr: eatenOfTarget,
  toGoStr: toGo,
  paceByNowStr: byNow,
);

const _energy = EnergyCardData(
  netKcal: 160,
  bandCopy: null,
  eatenKcal: 1620,
  burnedKcal: 1460,
  targetKcal: 2520,
  remainingKcal: 900,
  workoutDoneKcal: 428,
  workoutPlannedKcal: 502,
  workoutProjectedKcal: 930,
  workoutRows: [],
  carbTargetG: 300,
  proteinTargetG: 140,
  fatTargetG: 75,
  carbEatenG: 255,
  proteinEatenG: 73,
  fatEatenG: 38,
);

Widget frame(Widget card) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Container(
    color: AppColors.blackberry,
    alignment: Alignment.topCenter,
    padding: const EdgeInsets.all(18),
    child: RepaintBoundary(
      child: SizedBox(width: 376, child: card),
    ),
  ),
);

Widget card({
  CarbLoadFaceData? carb,
  bool expanded = false,
  DashboardFilter faceFilter = DashboardFilter.all,
  VoidCallback? onToggle,
  VoidCallback? onCarbBreakdown,
}) => EnergySummaryCard(
  face: faceFilter,
  expanded: expanded,
  data: _energy,
  carb: carb,
  onToggleExpanded: onToggle ?? () {},
  onCarbBreakdown: onCarbBreakdown ?? () {},
);

Future<void> golden(WidgetTester tester, Widget w, String name) async {
  await tester.pumpWidget(frame(w));
  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(loadHomeShellFonts);

  group('L1 goldens — LOAD face', () {
    testWidgets('collapsed · today behind (the walked 3 PM state)',
        (tester) async {
      await golden(tester, card(carb: face()), 'load_face_collapsed_behind');
    });

    testWidgets('collapsed · today on pace (word form)', (tester) async {
      await golden(
        tester,
        card(
          carb: face(
            main: 'On pace',
            sub: '322 of 544 g',
            word: true,
            fill: 0.5919,
            tick: 0.5993,
          ),
        ),
        'load_face_collapsed_on_pace',
      );
    });

    testWidgets('collapsed · loaded flip (CD-5)', (tester) async {
      await golden(
        tester,
        card(
          carb: face(
            label: 'LOADED · DAY 2 OF 3',
            main: 'Loaded',
            sub: '547 of 544 g',
            word: true,
            fill: 1,
            tick: null,
            loaded: true,
            eatenOfTarget: '547 of 544 g',
            toGo: '0 g to go',
            byNow: null,
          ),
        ),
        'load_face_collapsed_loaded',
      );
    });

    testWidgets('collapsed · future day (planned form)', (tester) async {
      await golden(
        tester,
        card(
          carb: face(
            label: 'CARB LOAD · DAY 3 OF 3',
            main: '680 g',
            sub: 'planned',
            fill: 0,
            tick: null,
            rel: CarbDayRel.future,
            eatenOfTarget: '0 of 680 g',
            toGo: '680 g to go',
            byNow: null,
          ),
        ),
        'load_face_collapsed_future',
      );
    });

    testWidgets('collapsed · past day (outcome form)', (tester) async {
      await golden(
        tester,
        card(
          carb: face(
            label: 'CARB LOAD · DAY 1 OF 3',
            main: '521 g',
            sub: 'of 544 g',
            fill: 0.9577,
            tick: null,
            rel: CarbDayRel.past,
            eatenOfTarget: '521 of 544 g',
            toGo: '23 g to go',
            byNow: null,
          ),
        ),
        'load_face_collapsed_past',
      );
    });

    testWidgets('expanded · today (Q-D9 admitted form)', (tester) async {
      await golden(
        tester,
        card(carb: face(), expanded: true),
        'load_face_expanded_today',
      );
    });
  });

  group('L2 — face selection and E1/E2', () {
    testWidgets('LOAD replaces the All face only; Workout stays untouched',
        (tester) async {
      await tester.pumpWidget(frame(card(carb: face())));
      expect(find.text('CARB LOAD · DAY 2 OF 3'), findsOneWidget);
      expect(find.text('NET BALANCE'), findsNothing);

      await tester.pumpWidget(
        frame(card(carb: face(), faceFilter: DashboardFilter.workout)),
      );
      expect(find.text("TODAY'S WORKOUT"), findsOneWidget);
      expect(find.text('CARB LOAD · DAY 2 OF 3'), findsNothing);
    });

    testWidgets('no carb data → the ordinary All face (CD-1 negative)',
        (tester) async {
      await tester.pumpWidget(frame(card()));
      expect(find.text('NET BALANCE'), findsOneWidget);
      expect(find.textContaining('CARB LOAD'), findsNothing);
    });

    testWidgets('E1 toggles on LOAD (Q-D9: expansion admitted)',
        (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
        frame(card(carb: face(), onToggle: () => toggles++)),
      );
      await tester.tap(
        find.byKey(const ValueKey('macro_dashboard.energy_expand')),
      );
      expect(toggles, 1);
    });

    testWidgets('E2 on LOAD routes to the carb destination, not the pager',
        (tester) async {
      var carbOpens = 0;
      await tester.pumpWidget(
        frame(
          card(
            carb: face(),
            expanded: true,
            onCarbBreakdown: () => carbOpens++,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('macro_dashboard.carb_full_breakdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('macro_dashboard.full_breakdown')),
        findsNothing,
        reason: 'the net-balance pager button must not render on LOAD',
      );
      await tester.tap(
        find.byKey(const ValueKey('macro_dashboard.carb_full_breakdown')),
      );
      expect(carbOpens, 1);
    });

    testWidgets('expanded strings render the registered forms', (tester) async {
      await tester.pumpWidget(frame(card(carb: face(), expanded: true)));
      expect(find.text('295 of 544 g'), findsOneWidget);
      expect(find.text('249 g to go'), findsOneWidget);
      expect(find.text('pace 326 g by now'), findsOneWidget);
    });
  });
}
