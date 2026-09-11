// Golden conformance — home-shell@v1.
// Manifest: docs/ssot/conformance/design/home-shell.goldens.yaml (RATIFIED
// Xuan 2026-09-06): 11 goldens at token-resolved colors — the glass /
// glass-sheet recipes and the blackberry-60% scrim from tokens.md
// §Materials, never the export's ad-hoc values where the two differ
// (compact header row = glass; scrim = blackberry 60%).
//
// The calendar goldens render the PINNED canonical mock month (August 2026
// as drawn, verified 2026-09-06) and the ratified sparse re-mock; the
// divergence pairs (dot-no-tint 14/21/28, tint-no-dot 8/15, SKIPPED 11)
// must survive any re-mock.
//
// Regenerate with:
//   flutter test test/features/home_shell/home_shell_goldens_test.dart --update-goldens
// RULE: a golden may only be regenerated AFTER the design spec changes —
// never to make a red test pass; regeneration commits cite the spec change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_date_header.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_materials.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

import 'home_shell_test_fonts.dart';

// ---------------------------------------------------------------------------
// Frame + mock ground (the glass recipes need recognizable content behind).
// ---------------------------------------------------------------------------

/// Deterministic mock timeline blocks behind the glass chrome (a
/// non-scrolling ListView so short frames clip instead of overflowing).
Widget _ground() => ListView(
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
  children: [
    ...[
      for (var i = 0; i < 8; i++) ...[
        Container(
          height: 84,
          decoration: BoxDecoration(
            color: i.isEven
                ? AppColors.blackberryLight
                : AppColors.orange.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.cream.withValues(alpha: 0.12)),
          ),
          padding: const EdgeInsets.all(14),
          alignment: Alignment.topLeft,
          child: Text(
            i.isEven ? 'Timeline card ${i + 1}' : 'Fuel window ${i + 1}',
            style: TextStyle(
              fontFamily: AppTextStyles.apercu,
              fontSize: 14,
              color: AppColors.cream.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ],
  ],
);

Widget _frame(Widget child, {double height = 852}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: AppColors.blackberry,
    body: SizedBox(width: 428, height: height, child: child),
  ),
);

Future<void> _golden(
  WidgetTester tester,
  Widget child,
  String name, {
  double height = 852,
  Duration? pumpFor,
}) async {
  tester.view.physicalSize = Size(428, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_frame(child, height: height));
  if (pumpFor != null) {
    await tester.pump();
    await tester.pump(pumpFor);
  } else {
    await tester.pump();
  }
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile('goldens/$name.png'),
  );
}

List<KyleTabBarDestination> _destinations(int count) => [
  KyleTabBarDestination(
    id: 'timeline',
    icon: FontAwesomeIcons.solidHouse.data,
    label: 'Timeline',
  ),
  KyleTabBarDestination(
    id: 'events',
    icon: FontAwesomeIcons.trophy.data,
    label: 'Events',
  ),
  KyleTabBarDestination(
    id: 'learn',
    icon: FontAwesomeIcons.graduationCap.data,
    label: 'Learn',
  ),
  if (count >= 4)
    KyleTabBarDestination(
      id: 'food',
      icon: FontAwesomeIcons.utensils.data,
      label: 'Food',
    ),
  if (count >= 5)
    KyleTabBarDestination(
      id: 'coach',
      icon: FontAwesomeIcons.userTie.data,
      label: 'Coach',
    ),
];

Widget _barOverGround({
  required List<KyleTabBarDestination> destinations,
  required String activeId,
  bool collapsed = false,
  ValueChanged<String>? onSelect,
}) => Stack(
  children: [
    Positioned.fill(child: _ground()),
    Positioned(
      left: 14,
      bottom: 28,
      child: KyleTabBar(
        destinations: destinations,
        activeId: activeId,
        collapsed: collapsed,
        maxWidth:
            428 -
            14 -
            KyleTabBar.utilitySlotGap -
            KyleTabBar.utilitySlotSize -
            14,
        onSelect: onSelect ?? (_) {},
      ),
    ),
  ],
);

// ---------------------------------------------------------------------------
// The pinned canonical mock month — August 2026 as drawn (goldens manifest).
// ---------------------------------------------------------------------------

Map<int, KyleCalendarDayData> _denseMonth() {
  const filled = [3, 5, 7, 10, 12, 14, 19, 21, 24, 26, 28, 31];
  const hollow = [22, 29];
  const tints = [3, 4, 5, 7, 8, 10, 12, 15, 17, 19, 24, 26, 29, 31];
  // Day 11 is the SKIPPED day: number renders, dot slot EMPTY, untinted.
  final days = <int, KyleCalendarDayData>{};
  for (var d = 1; d <= 31; d++) {
    final dot = filled.contains(d)
        ? CalendarDotState.done
        : hollow.contains(d)
        ? CalendarDotState.planned
        : CalendarDotState.none;
    final tinted = tints.contains(d);
    if (dot != CalendarDotState.none || tinted) {
      days[d] = KyleCalendarDayData(dot: dot, tinted: tinted);
    }
  }
  return days;
}

/// The sparse re-mock: 3 workouts / 3 tints, keeping one dot-no-tint day
/// (20) and one tint-no-dot day (22). Must read CALM.
Map<int, KyleCalendarDayData> _sparseMonth() => const {
  6: KyleCalendarDayData(dot: CalendarDotState.done, tinted: true),
  13: KyleCalendarDayData(dot: CalendarDotState.done, tinted: true),
  20: KyleCalendarDayData(dot: CalendarDotState.done),
  22: KyleCalendarDayData(tinted: true),
};

Widget _summonedSheet({
  required DateTime month,
  required DateTime today,
  required DateTime selected,
  required Map<int, KyleCalendarDayData> days,
}) => Stack(
  children: [
    Positioned.fill(child: _ground()),
    // The ruled scrim — blackberry 60%, between the page and the sheet.
    Positioned.fill(child: ColoredBox(color: AppMaterials.sheetScrim)),
    Positioned(
      top: KyleCalendarSheet.topInset,
      left: 0,
      right: 0,
      bottom: 0,
      child: KyleCalendarSheet(
        month: month,
        today: today,
        selected: selected,
        days: days,
        onPreviousMonth: () {},
        onNextMonth: () {},
        onDayTap: (_) {},
        onTodayTap: () {},
        onDismiss: () {},
      ),
    ),
  ],
);

void main() {
  setUpAll(loadHomeShellFonts);

  // ---- tab bar ----

  testWidgets('tab_bar_expanded_3', (tester) async {
    await _golden(
      tester,
      _barOverGround(destinations: _destinations(3), activeId: 'timeline'),
      'tab_bar_expanded_3',
    );
  });

  testWidgets('tab_bar_expanded_5', (tester) async {
    await _golden(
      tester,
      _barOverGround(destinations: _destinations(5), activeId: 'timeline'),
      'tab_bar_expanded_5',
    );
  });

  testWidgets('tab_bar_collapsed', (tester) async {
    await _golden(
      tester,
      _barOverGround(
        destinations: _destinations(3),
        activeId: 'timeline',
        collapsed: true,
      ),
      'tab_bar_collapsed',
    );
  });

  testWidgets('tab_bar_morph_mid', (tester) async {
    // Fixed animation timestamp: 170 ms into the 340 ms collapse morph,
    // which targets the LEFT corner (Q2 coherence).
    tester.view.physicalSize = const Size(428, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var collapsed = false;
    late StateSetter setOuterState;
    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (context, setState) {
            setOuterState = setState;
            return _barOverGround(
              destinations: _destinations(3),
              activeId: 'timeline',
              collapsed: collapsed,
            );
          },
        ),
      ),
    );
    await tester.pump();
    setOuterState(() => collapsed = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/tab_bar_morph_mid.png'),
    );
  });

  testWidgets('tab_bar_switch_transit_mid', (tester) async {
    // Mid-transit frame: highlight BETWEEN items (travel + width morph)
    // WITH the lensing displacement active behind it (tb4/tb6 pin the
    // numbers; this golden pins the look).
    tester.view.physicalSize = const Size(428, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var active = 'timeline';
    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (context, setState) => _barOverGround(
            destinations: _destinations(3),
            activeId: active,
            onSelect: (id) => setState(() => active = id),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('kyle_tab_bar.item.learn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/tab_bar_switch_transit_mid.png'),
    );
  });

  // ---- date header ----

  Widget headerOverGround(KyleDateHeader header) => Stack(
    children: [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: _ground(),
        ),
      ),
      Positioned(top: 0, left: 0, right: 0, child: header),
    ],
  );

  testWidgets('date_header_rest_today', (tester) async {
    await _golden(
      tester,
      headerOverGround(
        KyleDateHeader(
          date: DateTime(2026, 8, 31),
          now: DateTime(2026, 8, 31),
          compact: false,
          onSummonCalendar: () {},
          onSettingsTap: () {},
          onPreviousDay: () {},
          onNextDay: () {},
        ),
      ),
      'date_header_rest_today',
      height: 400,
    );
  });

  testWidgets('date_header_rest_weekday', (tester) async {
    await _golden(
      tester,
      headerOverGround(
        KyleDateHeader(
          date: DateTime(2026, 8, 12), // Wednesday — the pinned variant
          now: DateTime(2026, 8, 31),
          compact: false,
          onSummonCalendar: () {},
          onSettingsTap: () {},
          onPreviousDay: () {},
          onNextDay: () {},
        ),
      ),
      'date_header_rest_weekday',
      height: 400,
    );
  });

  testWidgets('date_header_compact', (tester) async {
    // THE ROW ITSELF renders the glass recipe (RULED 2026-09-06 — not the
    // export's blur-14 fade); content scrolled beneath it.
    await _golden(
      tester,
      Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              // Scrolled so a dark timeline card sits under the glass row.
              offset: const Offset(0, -230),
              child: _ground(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: KyleDateHeader(
              date: DateTime(2026, 8, 31),
              now: DateTime(2026, 8, 31),
              compact: true,
              onSummonCalendar: () {},
              onSettingsTap: () {},
              onPreviousDay: () {},
              onNextDay: () {},
            ),
          ),
        ],
      ),
      'date_header_compact',
      height: 400,
    );
  });

  // ---- calendar sheet ----

  testWidgets('calendar_sheet_dense_month', (tester) async {
    await _golden(
      tester,
      _summonedSheet(
        month: DateTime(2026, 8, 1),
        today: DateTime(2026, 8, 31), // cream-FILLED
        selected: DateTime(2026, 8, 12), // cream ring (selected != today)
        days: _denseMonth(),
      ),
      'calendar_sheet_dense_month',
    );
  });

  testWidgets('calendar_sheet_sparse_month', (tester) async {
    await _golden(
      tester,
      _summonedSheet(
        month: DateTime(2026, 9, 1),
        today: DateTime(2026, 9, 28),
        selected: DateTime(2026, 9, 28), // selected == today -> filled
        days: _sparseMonth(),
      ),
      'calendar_sheet_sparse_month',
    );
  });

  testWidgets('calendar_cell_spec_card', (tester) async {
    // Every cell treatment in one frame, enlarged (scale 2) so the
    // three-slot anatomy is legible.
    Widget labeled(String label, KyleCalendarDayCell cell) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 88, child: cell),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 11,
            color: AppColors.cream.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    const dotRows = [
      (CalendarDotState.planned, 'PLANNED\nhollow'),
      (CalendarDotState.done, 'DONE\nfilled'),
      (CalendarDotState.none, 'SKIPPED\nempty'),
      (CalendarDotState.none, 'rest\nempty'),
    ];

    await _golden(
      tester,
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cell spec — three fixed slots',
              style: TextStyle(
                fontFamily: AppTextStyles.sansita,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 20),
            // The four dot rows, tint OFF.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, row) in dotRows.indexed)
                  labeled(
                    row.$2,
                    KyleCalendarDayCell(
                      day: 11 + i,
                      data: KyleCalendarDayData(dot: row.$1),
                      scale: 1.7,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // The same rows, tint ON.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (i, row) in dotRows.indexed)
                  labeled(
                    '${row.$2}\n+ tint',
                    KyleCalendarDayCell(
                      day: 11 + i,
                      data: KyleCalendarDayData(dot: row.$1, tinted: true),
                      scale: 1.7,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Today / selected / selected==today treatments.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                labeled(
                  'today\nFILLED',
                  const KyleCalendarDayCell(
                    day: 31,
                    data: KyleCalendarDayData(),
                    isToday: true,
                    scale: 1.7,
                  ),
                ),
                labeled(
                  'selected\nring',
                  const KyleCalendarDayCell(
                    day: 12,
                    data: KyleCalendarDayData(),
                    isSelected: true,
                    scale: 1.7,
                  ),
                ),
                labeled(
                  'selected==today\nfilled',
                  const KyleCalendarDayCell(
                    day: 31,
                    data: KyleCalendarDayData(),
                    isToday: true,
                    isSelected: true,
                    scale: 1.7,
                  ),
                ),
                const SizedBox(width: 88),
              ],
            ),
          ],
        ),
      ),
      'calendar_cell_spec_card',
      height: 620,
    );
  });
}
