// Gesture/behavior conformance — home-shell@v1.
// Manifest: docs/ssot/conformance/design/home-shell.gestures.yaml (RATIFIED
// Xuan 2026-09-06). One test per manifest row (tb1–tb7, dh1–dh6, cs2–cs9);
// each executes the real code path — the shell screen through the real
// providers with only data sources seeded (the macro-dashboard suite's
// recipe), or the real component/assembler for component-scoped rows.
//
// Pinned values (the manifest's former TBD-at-implementation pins):
//   tb1 collapse_threshold_px: 88 · tb2 expand_threshold_px: 64,
//   hysteresis_px: 24 · tb4 duration_ms 340, easing cubic-bezier(0.32,0.72,0,1)
//   · tb6 distortion_magnitude 6.0 px, falloff 8.0 px half-displacement band
//   · dh3 compact_threshold_px: 56 · cs2 commit_threshold_px: 90.
//
// Seam rule (docs/test/README.md): fixtures are PRODUCER-shaped — mark-done
// writes actual_time = planned_time (Q-D7), sync stamps a measured
// actual_time + garmin summary id, skip writes status only; meal-log days
// are 'yyyy-MM-dd' log_date strings as the producers write them. The date
// write path (day tap / chevrons) runs through the REAL
// CalendarSelectedDate notifier.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/home_shell/application/home_shell_calendar_assembler.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/home_shell_chrome.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/providers/home_shell_providers.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/widgets/home_shell_calendar_host.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_date_header.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_materials.dart';

import '../../helpers/widget_test_harness.dart';
import 'home_shell_test_fonts.dart';

// ---------------------------------------------------------------------------
// Producer-shaped fixtures. The mock day is in the past so derivations are
// deterministic against the real clock the shell providers use.
// ---------------------------------------------------------------------------

final _day = DateTime(2026, 8, 14);

Activity _activity({
  required String id,
  required DateTime planned,
  ActivityStatus status = ActivityStatus.planned,
  DateTime? actual,
  String? garminSummaryId,
  ActivityType type = ActivityType.running,
}) => Activity(
  id: id,
  userId: 'u1',
  activityType: type,
  title: id,
  scheduledDateTime: planned,
  plannedTime: planned,
  actualTime: actual,
  status: status,
  garminSummaryId: garminSummaryId,
  durationMinutes: 60,
  createdAt: _day,
  updatedAt: _day,
);

/// Mark-done producer shape (Q-D7): actual_time = planned_time.
Activity _doneConfirmed(String id, DateTime planned) => _activity(
  id: id,
  planned: planned,
  status: ActivityStatus.completed,
  actual: planned,
);

/// Sync producer shape: measured actual_time (≠ planned) + summary id.
Activity _doneVerified(String id, DateTime planned) => _activity(
  id: id,
  planned: planned,
  status: ActivityStatus.completed,
  actual: planned.add(const Duration(minutes: 7)),
  garminSummaryId: 'g-$id',
);

/// Skip producer shape: status only; actual_time stays null.
Activity _skippedActive(String id, DateTime planned) =>
    _activity(id: id, planned: planned, status: ActivityStatus.skipped);

MealLog _meal(String id, DateTime eatenAt) => MealLog(
  id: id,
  userId: 'u1',
  logDate: '2026-08-14',
  slot: MealSlot.snack,
  name: 'Meal $id',
  source: MealLogSource.manual,
  components: const [],
  calories: 300,
  carbsG: 40,
  proteinG: 10,
  fatG: 8,
  eatenAt: eatenAt,
  createdAt: _day,
  updatedAt: _day,
);

DailyMacroTargets _targets() => DailyMacroTargets(
  id: 't1',
  userId: 'u1',
  targetDate: _day,
  carbG: 596,
  protG: 130,
  fatG: 138,
  tdee: 4152,
  rmr: 1908,
  sessionKcal: 1538,
  neatKcal: 394.9,
  mode: 'prospective',
  algorithmVersion: 'v6.0.0',
  createdAt: _day,
  updatedAt: _day,
  weightKg: 75,
);

class _FixedSelectedDate extends CalendarSelectedDate {
  @override
  DateTime build() => _day;
}

class _SeededActivitiesController extends ActivitiesController {
  @override
  FutureOr<List<Activity>> build() => [
    _doneVerified('swim', DateTime(2026, 8, 14, 8, 0)),
    _doneConfirmed('lift', DateTime(2026, 8, 14, 12, 0)),
    _activity(id: 'run', planned: DateTime(2026, 8, 14, 17, 30)),
  ];
}

class _SeededDailyMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async => DailyMacrosState(
    selectedDate: _day,
    dailyMacros: _targets(),
    weeklyMacros: List<DailyMacroTargets?>.filled(7, _targets()),
  );
}

List<Override> _shellOverrides() => [
  userIdProvider.overrideWith((ref) async => 'u1'),
  calendarSelectedDateProvider.overrideWith(_FixedSelectedDate.new),
  activitiesControllerProvider.overrideWith(_SeededActivitiesController.new),
  dailyMacrosControllerProvider.overrideWith(_SeededDailyMacrosController.new),
  // A long day of meals so the timeline actually scrolls past the pinned
  // thresholds.
  mealLogsForDateProvider.overrideWith(
    (ref, date) => Stream.value([
      for (var i = 0; i < 10; i++)
        _meal('m$i', DateTime(2026, 8, 14, 7 + i, 0)),
    ]),
  ),
  consumedTotalsForDateProvider.overrideWith(
    (ref, date) => Stream.value(
      const ConsumedTotals(calories: 1650, carbsG: 262, proteinG: 68, fatG: 36),
    ),
  ),
  homeShellLoggedDatesProvider.overrideWith(
    (ref, args) => Stream.value({'2026-08-14'}),
  ),
];

/// The switched-over `/main` composition: [HomeShellChrome] around the home
/// tab's content, exactly as [TabsScreen] mounts it (tab switching drives a
/// real active-id state the way the IndexedStack index does).
class _ShellHost extends StatefulWidget {
  const _ShellHost();

  @override
  State<_ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<_ShellHost> {
  String _active = 'timeline';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: HomeShellChrome(
        destinations: _destinations(3),
        activeTabId: _active,
        onSelectTab: (id) => setState(() => _active = id),
        showDateHeader: _active == 'timeline',
        body: Container(
          color: AppColors.blackberry,
          child: const MacroDashboardBody(
            topInset: HomeShellChrome.headerClearancePx,
          ),
        ),
      ),
    );
  }
}

/// dh2's parity host: the REAL KyleDateHeader wired to the REAL summon path
/// (showHomeShellCalendarSheet), with the compact state flippable the way a
/// scrolling composition would drive it (the home pins REST — ruling #4).
class _ParityHost extends ConsumerStatefulWidget {
  const _ParityHost();

  @override
  ConsumerState<_ParityHost> createState() => _ParityHostState();
}

class _ParityHostState extends ConsumerState<_ParityHost> {
  bool _compact = false;

  void flipCompact(bool value) => setState(() => _compact = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Align(
        alignment: Alignment.topCenter,
        child: KyleDateHeader(
          date: ref.watch(calendarSelectedDateProvider),
          compact: _compact,
          onSummonCalendar: () => showHomeShellCalendarSheet(context),
          onSettingsTap: () {},
          onPreviousDay: () {},
          onNextDay: () {},
        ),
      ),
    );
  }
}

Future<void> _pumpShell(WidgetTester tester) async {
  // The root design size (root_app_widget.dart: 393×852) — ScreenUtil scale
  // exactly 1.0, and the shipped add-row pills fit without overflow.
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpSeeded(
    tester,
    const _ShellHost(),
    overrides: _shellOverrides(),
    settle: true,
  );
}

/// The vertical timeline scrollable (the filter row scrolls horizontally).
Finder _timeline() => find.byWidgetPredicate(
  (w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical,
).first;

/// Scroll the timeline to an absolute offset (px) with ONE monotonic drag —
/// the position approaches [target] without ever overshooting, so a scroll
/// to inside the hysteresis band can never latch a threshold it shouldn't
/// have crossed (tb2's contract depends on the trajectory, not just the
/// landing).
Future<void> _scrollTo(WidgetTester tester, double target) async {
  final state = tester.state<ScrollableState>(_timeline());
  final start = state.position.pixels;
  if ((target - start).abs() < 1) return;
  final dir = (target - start).sign; // + = scroll down (finger drags up)
  final rect = tester.getRect(_timeline());
  // Start low in the list, clear of the pinned block and the tab bar.
  final g = await tester.startGesture(
    Offset(rect.center.dx, rect.bottom - 180),
  );
  // Consume touch slop; after this the finger tracks ~1:1.
  await g.moveBy(Offset(0, -dir * 20));
  await tester.pump(const Duration(milliseconds: 16));
  for (var i = 0; i < 200; i++) {
    final remaining = target - state.position.pixels;
    if (remaining.abs() < 0.5) break;
    final step = remaining.abs() < 24 ? remaining : 24 * remaining.sign;
    await g.moveBy(Offset(0, -step));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
  expect(
    tester.state<ScrollableState>(_timeline()).position.pixels,
    moreOrLessEquals(target, epsilon: 1),
    reason: 'scroll helper must land on the pinned offset',
  );
}

Finder _collapsedButton() =>
    find.byKey(const ValueKey('kyle_tab_bar.collapsed_button'));

Finder _highlight() => find.byKey(const ValueKey('kyle_tab_bar.highlight'));

/// The lens bubble (tb6, PROPOSED liquid-bubble amendment): the
/// LiquidLensBubble under the highlight key.
Finder _lensBubble() => find.byType(LiquidLensBubble);

// ---------------------------------------------------------------------------
// Component-scoped hosts
// ---------------------------------------------------------------------------

Widget _frame(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: AppColors.blackberry,
    body: Center(child: child),
  ),
);

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

void main() {
  setUpAll(loadHomeShellFonts);

  // =========================================================================
  // Tab bar (components/tab-bar.md)
  // =========================================================================

  // tb1_scroll_collapses (tab-bar Q1 trigger rule)
  // pin: collapse_threshold_px = 88
  testWidgets('tb1_scroll_collapses: scroll-down past the threshold -> '
      'COLLAPSED circular glass button, bottom-LEFT, active icon only; '
      'content scrolls under the bar in both states', (tester) async {
    await _pumpShell(tester);
    expect(find.byType(KyleTabBar), findsOneWidget);
    expect(_collapsedButton(), findsNothing);

    // Content scrolls under the bar (expanded): the scroll viewport reaches
    // the screen bottom, beneath the floating bar.
    final viewport = tester.getRect(_timeline());
    final barRect = tester.getRect(find.byType(KyleTabBar));
    expect(viewport.bottom, greaterThanOrEqualTo(barRect.top),
        reason: 'timeline must extend under the bar');

    await _scrollTo(tester, HomeShellChrome.tabBarCollapseThresholdPx + 20);
    expect(_collapsedButton(), findsOneWidget);
    // Bottom-LEFT anchor.
    final rect = tester.getRect(_collapsedButton());
    expect(rect.left, lessThan(60), reason: 'collapsed button anchors left');
    expect(rect.bottom, greaterThan(700), reason: 'collapsed button sits at the bottom');
    // Active tab's icon only.
    expect(
      find.descendant(of: _collapsedButton(), matching: find.byType(Icon)),
      findsOneWidget,
    );
    final icon = tester.widget<Icon>(
      find.descendant(of: _collapsedButton(), matching: find.byType(Icon)),
    );
    expect(icon.icon, FontAwesomeIcons.solidHouse.data,
        reason: 'the collapsed button shows the ACTIVE tab (house — Q4)');
    // Content still scrolls under in the collapsed state.
    expect(
      tester.getRect(_timeline()).bottom,
      greaterThanOrEqualTo(tester.getRect(_collapsedButton()).top),
    );
  });

  // tb2_scroll_reexpands (return path + hysteresis)
  // pins: expand_threshold_px = 64, hysteresis_px = 24
  testWidgets('tb2_scroll_reexpands: scroll-up -> EXPANDED; dithering inside '
      'the 64..88 hysteresis band never flaps the state', (tester) async {
    await _pumpShell(tester);

    // Expanded at rest; entering the band from below must NOT collapse.
    await _scrollTo(
      tester,
      HomeShellChrome.tabBarExpandThresholdPx + 12, // 76: inside the band
    );
    expect(_collapsedButton(), findsNothing,
        reason: 'inside the hysteresis band the expanded state holds');

    // Past the collapse threshold -> collapsed.
    await _scrollTo(tester, HomeShellChrome.tabBarCollapseThresholdPx + 30);
    expect(_collapsedButton(), findsOneWidget);

    // Back into the band from above must NOT re-expand.
    await _scrollTo(tester, HomeShellChrome.tabBarExpandThresholdPx + 12);
    expect(_collapsedButton(), findsOneWidget,
        reason: 'inside the hysteresis band the collapsed state holds');

    // Below the expand threshold (and at top) -> expanded again.
    await _scrollTo(tester, 0);
    expect(_collapsedButton(), findsNothing);
  });

  // tb3_collapsed_icon_is_active_tab (Q3)
  testWidgets('tb3_collapsed_icon_is_active_tab: with 3 AND 5 destinations '
      'the collapsed button shows the ACTIVE tab icon — never a fixed glyph',
      (tester) async {
    for (final count in [3, 5]) {
      for (final active in ['events', 'learn']) {
        await tester.pumpWidget(
          _frame(
            KyleTabBar(
              destinations: _destinations(count),
              activeId: active,
              collapsed: true,
              onSelect: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final icons = find.descendant(
          of: _collapsedButton(),
          matching: find.byType(Icon),
        );
        expect(icons, findsOneWidget, reason: 'count=$count active=$active');
        expect(
          tester.widget<Icon>(icons).icon,
          active == 'events'
              ? FontAwesomeIcons.trophy.data
              : FontAwesomeIcons.graduationCap.data,
          reason: 'count-independent active icon (count=$count)',
        );
      }
    }
  });

  // tb4_switch_travel (transition part 1)
  // pins: duration_ms = 340, easing = cubic-bezier(0.32,0.72,0,1)
  testWidgets('tb4_switch_travel: the highlight travels old -> new, position '
      'AND width animating; mid-transit it is BETWEEN the items',
      (tester) async {
    String active = 'timeline';
    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (context, setState) => KyleTabBar(
            destinations: _destinations(3),
            activeId: active,
            onSelect: (id) => setState(() => active = id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final restRect = tester.getRect(_highlight());
    final restWidth = restRect.width;

    await tester.tap(find.byKey(const ValueKey('kyle_tab_bar.item.learn')));
    await tester.pump(); // start travel
    await tester.pump(const Duration(milliseconds: 170)); // mid-transit
    final midRect = tester.getRect(_highlight());
    final learnRect = tester.getRect(
      find.byKey(const ValueKey('kyle_tab_bar.item.learn')),
    );
    expect(midRect.center.dx, greaterThan(restRect.center.dx + 5),
        reason: 'no teleport — the highlight left the old item');
    expect(midRect.center.dx, lessThan(learnRect.center.dx - 5),
        reason: 'mid-transit the highlight is BETWEEN the items');
    expect(midRect.width, greaterThan(restWidth + 4),
        reason: 'width animates too (the capsule stretches in transit)');

    await tester.pumpAndSettle();
    final endRect = tester.getRect(_highlight());
    expect((endRect.center.dx - learnRect.center.dx).abs(), lessThan(2),
        reason: 'travel completes on the new item');
    expect((endRect.width - restWidth).abs(), lessThan(2),
        reason: 'width relaxes at rest');
  });

  // tb5_switch_drag_tracking (transition part 2)
  testWidgets('tb5_switch_drag_tracking: a live drag moves the highlight '
      'fluidly under the finger; release commits to the nearest destination',
      (tester) async {
    String active = 'timeline';
    final selections = <String>[];
    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (context, setState) => KyleTabBar(
            destinations: _destinations(3),
            activeId: active,
            onSelect: (id) {
              selections.add(id);
              setState(() => active = id);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final start = tester.getCenter(
      find.byKey(const ValueKey('kyle_tab_bar.item.timeline')),
    );
    final gesture = await tester.startGesture(start);
    // Fluid tracking: several small moves, highlight follows each.
    double? lastDx;
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final dx = tester.getRect(_highlight()).center.dx;
      if (lastDx != null) {
        expect(dx, greaterThan(lastDx),
            reason: 'highlight tracks the finger — no snapping mid-drag');
      }
      lastDx = dx;
    }
    expect(selections, isEmpty, reason: 'no commit while the drag is live');
    await gesture.up();
    await tester.pumpAndSettle();
    // 120 px from the timeline centre lands nearest the middle item.
    expect(selections, ['events'],
        reason: 'release commits to the nearest destination');
    final endRect = tester.getRect(_highlight());
    final eventsRect = tester.getRect(
      find.byKey(const ValueKey('kyle_tab_bar.item.events')),
    );
    expect((endRect.center.dx - eventsRect.center.dx).abs(), lessThan(2),
        reason: 'the travel animation completed from the release position');
  });

  // tb6_liquid_lens_bubble (transition part 3 + Q1 highlight — PROPOSED
  // amendment, intake 2026-09-06-tab-bar-liquid-bubble, pending Xuan's
  // ratification: the Bevel-style bubble is present at REST on the active
  // item and travels with refraction in transit, superseding the
  // cream-fill highlight and the old lens-only-in-transit negative).
  // pins: thickness 14 · refractiveIndex 1.35 · chromaticAberration 0.25 ·
  //       bulge 6px over the bar border
  testWidgets('tb6_liquid_lens_bubble: the liquid-glass bubble sits on the '
      'active item at rest, bulges past the bar border, travels in transit, '
      'and fades through the collapse morph', (tester) async {
    String active = 'timeline';
    var collapsed = false;
    late StateSetter setOuter;
    await tester.pumpWidget(
      _frame(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return KyleTabBar(
              destinations: _destinations(3),
              activeId: active,
              collapsed: collapsed,
              onSelect: (id) => setState(() => active = id),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AT REST: the bubble is present over the active item and overflows the
    // bar's border (the Bevel bulge).
    expect(_lensBubble(), findsOneWidget,
        reason: 'the bubble is the resting highlight (PROPOSED)');
    final barRect = tester.getRect(find.byType(GlassSurface).first);
    final bubbleRect = tester.getRect(_highlight());
    expect(bubbleRect.top, lessThan(barRect.top),
        reason: 'the bubble bulges over the bar border');
    expect(bubbleRect.bottom, greaterThan(barRect.bottom));
    final timelineRect = tester.getRect(
      find.byKey(const ValueKey('kyle_tab_bar.item.timeline')),
    );
    expect((bubbleRect.center.dx - timelineRect.center.dx).abs(), lessThan(2),
        reason: 'the bubble rests on the active item');

    // IN TRANSIT: the same bubble travels between items (refraction is the
    // shader's; appearance golden-held in tab_bar_switch_transit_mid).
    await tester.tap(find.byKey(const ValueKey('kyle_tab_bar.item.learn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    expect(_lensBubble(), findsOneWidget);
    final midRect = tester.getRect(_highlight());
    expect(midRect.center.dx, greaterThan(timelineRect.center.dx + 5));
    await tester.pumpAndSettle();

    // COLLAPSE MORPH: the bubble fades out — the collapsed button is its
    // own glass circle.
    setOuter(() => collapsed = true);
    await tester.pumpAndSettle();
    expect(_lensBubble(), findsNothing,
        reason: 'no bubble in the collapsed state');
  });

  // tb7_utility_slot_reserved (Q2, option a) — NEGATIVE / geometry
  testWidgets('tb7_utility_slot_reserved: NOTHING renders in the '
      'bottom-right utility slot in either state; the collapse morph targets '
      'the LEFT corner', (tester) async {
    await _pumpShell(tester);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final slotRect = Rect.fromLTWH(
      size.width - 14 - KyleTabBar.utilitySlotSize,
      size.height - 16 - KyleTabBar.utilitySlotSize,
      KyleTabBar.utilitySlotSize,
      KyleTabBar.utilitySlotSize,
    );

    void expectSlotEmpty(String state) {
      // The bar itself never occupies the slot region.
      final barRect = tester.getRect(find.byType(KyleTabBar));
      expect(barRect.overlaps(slotRect), isFalse,
          reason: 'the bar never occupies the slot ($state)');
      // And no other shell chrome renders there: the header owns the top
      // edge only, and the shell composes exactly these two chrome layers —
      // so an empty intersection with both IS the empty slot.
      final headerRect = tester.getRect(find.byType(KyleDateHeader));
      expect(headerRect.overlaps(slotRect), isFalse,
          reason: 'slot is EMPTY in v1 ($state)');
    }

    expectSlotEmpty('expanded');
    await _scrollTo(tester, HomeShellChrome.tabBarCollapseThresholdPx + 30);
    expect(_collapsedButton(), findsOneWidget);
    expect(tester.getRect(_collapsedButton()).left, lessThan(60),
        reason: 'collapse morph targets the LEFT corner');
    expectSlotEmpty('collapsed');
  });

  // =========================================================================
  // Date header (components/date-header.md)
  // =========================================================================

  // dh1_title_tap_summons_sheet (Q1 REST summon path)
  testWidgets('dh1_title_tap_summons_sheet', (tester) async {
    await _pumpShell(tester);
    expect(find.byType(KyleCalendarSheet), findsNothing);
    await tester.tap(find.byKey(const ValueKey('kyle_date_header.title')));
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsOneWidget);
  });

  // dh2_compact_button_summons_same_sheet (summon parity)
  // Ruling #4 note: the home pins its header in REST, so the COMPACT path
  // is exercised by flipping the real component's state in a parity host —
  // the contract is the ONE onSummonCalendar callback (the real
  // showHomeShellCalendarSheet), and both states route through it.
  testWidgets('dh2_compact_button_summons_same_sheet: both entry points '
      'summon the SAME sheet component and state', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpSeeded(
      tester,
      const _ParityHost(),
      overrides: _shellOverrides(),
      settle: true,
    );

    // Path A: REST title.
    await tester.tap(find.byKey(const ValueKey('kyle_date_header.title')));
    await tester.pumpAndSettle();
    final sheetA = tester.widget<KyleCalendarSheet>(
      find.byType(KyleCalendarSheet),
    );
    expect(find.byType(HomeShellCalendarHost), findsOneWidget);
    await tester.tapAt(const Offset(195, 20)); // scrim, above the sheet
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsNothing);

    // Path B: the COMPACT calendar button — same component, same callback.
    tester
        .state<_ParityHostState>(find.byType(_ParityHost))
        .flipCompact(true);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('kyle_date_header.calendar_button')),
    );
    await tester.pumpAndSettle();
    final sheetB = tester.widget<KyleCalendarSheet>(
      find.byType(KyleCalendarSheet),
    );
    expect(find.byType(HomeShellCalendarHost), findsOneWidget,
        reason: 'one component, two entry points — identical host');
    // Identity of state, not just "a sheet appeared": same month, same
    // selected day, same today.
    expect(sheetB.month, sheetA.month);
    expect(sheetB.selected, sheetA.selected);
    expect(sheetB.today, sheetA.today);
  });

  // dh3_pinned_block_dissolve (ruling #4 — replaces the REST⇄COMPACT scroll
  // pair: the pinned instrument block never scrolls; the timeline runs
  // beneath it and dissolves under its backdrop)
  testWidgets('dh3_pinned_block_dissolve: the block (header + energy card + '
      'filters + add row) never scrolls; the timeline dissolves under it',
      (tester) async {
    await _pumpShell(tester);
    expect(find.byKey(const ValueKey('kyle_date_header.rest')), findsOneWidget);

    final headerBefore =
        tester.getRect(find.byKey(const ValueKey('kyle_date_header.rest')));
    final cardBefore = tester.getRect(
      find.byKey(const ValueKey('macro_dashboard.energy_card')),
    );

    await _scrollTo(tester, 150);

    // The block is PINNED: header stays REST at the same position, energy
    // card unmoved, no compact state ever appears on the home.
    expect(find.byKey(const ValueKey('kyle_date_header.rest')), findsOneWidget,
        reason: 'the home header stays REST (ruling #4)');
    expect(
      find.byKey(const ValueKey('kyle_date_header.compact')),
      findsNothing,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('kyle_date_header.rest'))),
      headerBefore,
      reason: 'the pinned block never scrolls',
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey('macro_dashboard.energy_card')),
      ),
      cardBefore,
      reason: 'S-1 glanceability: the energy card holds its place',
    );
    // The timeline runs beneath the block through the dissolve layer.
    expect(find.byType(GlassTopFade), findsOneWidget,
        reason: 'the block sits on its GlassTopFade dissolve');
    expect(
      tester.state<ScrollableState>(_timeline()).position.pixels,
      moreOrLessEquals(150, epsilon: 1),
      reason: 'the timeline itself scrolled',
    );

    await _scrollTo(tester, 0);
    expect(find.byKey(const ValueKey('kyle_date_header.rest')), findsOneWidget);
  });

  // dh4_chevrons_navigate_adjacent_day (Q2)
  testWidgets('dh4_chevrons_navigate_adjacent_day: chevrons move one day, '
      'no sheet is summoned', (tester) async {
    await _pumpShell(tester);
    final el = tester.element(find.byType(HomeShellChrome));
    final container = ProviderScope.containerOf(el, listen: false);
    expect(container.read(calendarSelectedDateProvider), _day);

    await tester.tap(find.byKey(const ValueKey('kyle_date_header.prev_day')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarSelectedDateProvider),
      _day.subtract(const Duration(days: 1)),
      reason: '"<" shows the previous day',
    );
    expect(find.byType(KyleCalendarSheet), findsNothing,
        reason: 'a chevron tap never summons the sheet');

    await tester.tap(find.byKey(const ValueKey('kyle_date_header.next_day')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kyle_date_header.next_day')));
    await tester.pumpAndSettle();
    expect(
      container.read(calendarSelectedDateProvider),
      _day.add(const Duration(days: 1)),
      reason: '">" shows the next day',
    );
    expect(find.byType(KyleCalendarSheet), findsNothing);
  });

  // dh5_no_screen_level_horizontal_swipe — NEGATIVE (hard constraint)
  testWidgets('dh5_no_screen_level_horizontal_swipe: a horizontal drag over '
      'the timeline changes no day and translates nothing; the workout card '
      'under the finger still gets its G-set', (tester) async {
    await _pumpShell(tester);
    final el = tester.element(find.byType(HomeShellChrome));
    final container = ProviderScope.containerOf(el, listen: false);
    final before = container.read(calendarSelectedDateProvider);

    // Drag over open timeline space (below the header, above the bar).
    final listRect = tester.getRect(_timeline());
    final probe = _timeline();
    final anchorBefore = tester.getTopLeft(probe);
    final gesture = await tester.startGesture(
      Offset(listRect.center.dx, listRect.center.dy),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(calendarSelectedDateProvider), before,
        reason: 'ZERO screen-level day change from a horizontal drag');
    expect(tester.getTopLeft(probe), anchorBefore,
        reason: 'zero screen-level translation');

    // The workout card still owns horizontal gestures (G4 reveal on the
    // non-verified DONE_CONFIRMED card — verified cards deliberately have
    // no Skip affordance, and a passive-skipped card offers only G1
    // recovery).
    await tester.scrollUntilVisible(
      find.text('lift'),
      200,
      scrollable: _timeline(),
    );
    await tester.pumpAndSettle();
    final cardGesture = await tester.startGesture(
      tester.getCenter(find.text('lift').first),
    );
    for (var i = 0; i < 12; i++) {
      await cardGesture.moveBy(const Offset(-90 / 12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await cardGesture.up();
    await tester.pumpAndSettle();
    final revealed =
        find.text('Skip').evaluate().isNotEmpty ||
        find.text('Unskip').evaluate().isNotEmpty;
    expect(revealed, isTrue,
        reason: 'the card under the finger still receives its own G-set');
    expect(container.read(calendarSelectedDateProvider), before);
  });

  // dh6_title_copy_register (Q1, weekday variant pinned 2026-09-06)
  testWidgets('dh6_title_copy_register: "Today, {Month D} ˅" on the current '
      'day; "{Weekday}, {Month D} ˅" otherwise', (tester) async {
    final semantics = tester.ensureSemantics();
    final today = DateTime(2026, 8, 31);

    await tester.pumpWidget(
      _frame(
        KyleDateHeader(
          date: today,
          compact: false,
          now: today,
          onSummonCalendar: () {},
          onSettingsTap: () {},
          onPreviousDay: () {},
          onNextDay: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today, August 31'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Today, August 31 ˅'),
      findsOneWidget,
      reason: 'the register includes the summon glyph',
    );

    await tester.pumpWidget(
      _frame(
        KyleDateHeader(
          date: DateTime(2026, 8, 12), // a Wednesday
          compact: false,
          now: today,
          onSummonCalendar: () {},
          onSettingsTap: () {},
          onPreviousDay: () {},
          onNextDay: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wednesday, August 12'), findsOneWidget,
        reason: 'the weekday replaces "Today"; nothing else changes');
    expect(find.bySemanticsLabel('Wednesday, August 12 ˅'), findsOneWidget);
    semantics.dispose();
  });

  // =========================================================================
  // Calendar sheet (components/calendar-sheet.md)
  // =========================================================================

  Future<void> summonSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('kyle_date_header.title')));
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsOneWidget);
  }

  // cs2_grabber_pull_dismisses_with_snapback (CS-2)
  // pin: commit_threshold_px = 90
  testWidgets('cs2_grabber_pull_dismisses_with_snapback', (tester) async {
    await _pumpShell(tester);
    await summonSheet(tester);

    // Negative half first: a short pull released early SNAPS BACK.
    final grabber = find.byKey(const ValueKey('kyle_calendar_sheet.grabber'));
    await tester.timedDrag(
      grabber,
      const Offset(0, 40),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsOneWidget,
        reason: 'a pull short of the commit threshold snaps back — sheet open');

    // Past the commit threshold -> dismiss.
    await tester.timedDrag(
      grabber,
      Offset(0, KyleCalendarSheet.dismissThresholdPx + 40),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsNothing);
  });

  // cs3_scrim_tap_dismisses (CS-3)
  testWidgets('cs3_scrim_tap_dismisses', (tester) async {
    await _pumpShell(tester);
    await summonSheet(tester);
    await tester.tapAt(const Offset(195, 20)); // above the sheet's top inset
    await tester.pumpAndSettle();
    expect(find.byType(KyleCalendarSheet), findsNothing);
  });

  // cs4_day_tap_navigates_and_dismisses (CS-4) — the COMBINED contract.
  testWidgets('cs4_day_tap_navigates_and_dismisses: home date changed AND '
      'sheet gone, in one test', (tester) async {
    await _pumpShell(tester);
    await summonSheet(tester);
    final el = tester.element(find.byType(HomeShellChrome));
    final container = ProviderScope.containerOf(el, listen: false);

    await tester.tap(
      find.byKey(const ValueKey('kyle_calendar_sheet.day_20')),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(calendarSelectedDateProvider),
      DateTime(2026, 8, 20),
      reason: 'home navigated to the tapped date (real notifier write path)',
    );
    expect(find.byType(KyleCalendarSheet), findsNothing,
        reason: 'AND the sheet dismissed — one combined contract');
  });

  // cs5_month_navigation_keeps_sheet (CS-5)
  testWidgets('cs5_month_navigation_keeps_sheet', (tester) async {
    await _pumpShell(tester);
    await summonSheet(tester);
    expect(find.text('August 2026'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('kyle_calendar_sheet.next_month')),
    );
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.byType(KyleCalendarSheet), findsOneWidget,
        reason: 'the sheet stays open across month navigation');
    await tester.tap(
      find.byKey(const ValueKey('kyle_calendar_sheet.prev_month')),
    );
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.byType(KyleCalendarSheet), findsOneWidget);
  });

  // cs6_today_pill (CS-6)
  testWidgets('cs6_today_pill: current day selected and navigated to',
      (tester) async {
    await _pumpShell(tester);
    await summonSheet(tester);
    final el = tester.element(find.byType(HomeShellChrome));
    final container = ProviderScope.containerOf(el, listen: false);
    expect(container.read(calendarSelectedDateProvider), _day);

    await tester.tap(
      find.byKey(const ValueKey('kyle_calendar_sheet.today_pill')),
    );
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(
      container.read(calendarSelectedDateProvider),
      DateTime(now.year, now.month, now.day),
      reason: 'Today pill selects + navigates to the current day',
    );
  });

  // cs7_dot_mapping (Q1: dot slot <- workout-card.md v3 states)
  testWidgets('cs7_dot_mapping: PLANNED hollow orange 2px/dark centre; both '
      'DONE states one filled electrolyte dot; SKIPPED active AND passive -> '
      'no dot; rest day -> no dot; multi-workout best-state fold',
      (tester) async {
    final month = DateTime(2026, 8, 1);
    final now = DateTime(2026, 8, 14); // fixed clock: 14th is "today"
    final days = assembleCalendarMonth(
      month: month,
      now: now,
      activities: [
        // Future planned day (20th) -> hollow ring.
        _activity(id: 'p', planned: DateTime(2026, 8, 20, 7)),
        // Mark-done (confirmed) on the 5th, sync-verified on the 6th — the
        // SAME dot for both.
        _doneConfirmed('dc', DateTime(2026, 8, 5, 7)),
        _doneVerified('dv', DateTime(2026, 8, 6, 7)),
        // Active skip on the 10th; passive skip (past planned, no actual,
        // no skip status) on the 3rd -> NO dot on either.
        _skippedActive('sa', DateTime(2026, 8, 10, 7)),
        _activity(id: 'sp', planned: DateTime(2026, 8, 3, 7)),
        // Multi-workout day (8th): one skipped + one completed -> the ONE
        // dot is filled (best state wins).
        _skippedActive('m1', DateTime(2026, 8, 8, 7)),
        _doneConfirmed('m2', DateTime(2026, 8, 8, 9)),
        // Multi-workout day (25th): planned + skipped -> hollow.
        _activity(id: 'm3', planned: DateTime(2026, 8, 25, 7)),
        _skippedActive('m4', DateTime(2026, 8, 25, 9)),
      ],
      loggedDates: const {},
    );

    expect(days[20]?.dot, CalendarDotState.planned);
    expect(days[5]?.dot, CalendarDotState.done);
    expect(days[6]?.dot, CalendarDotState.done,
        reason: 'no per-source distinction at cell size');
    expect(days[10]?.dot ?? CalendarDotState.none, CalendarDotState.none,
        reason: 'ACTIVE skip -> no dot (the banned failure signal)');
    expect(days[3]?.dot ?? CalendarDotState.none, CalendarDotState.none,
        reason: 'PASSIVE skip (derived, never written) -> no dot');
    expect(days[15], isNull, reason: 'rest day -> no dot, no entry');
    expect(days[8]?.dot, CalendarDotState.done,
        reason: 'multi-workout: any completed -> filled');
    expect(days[25]?.dot, CalendarDotState.planned,
        reason: 'multi-workout: else any planned -> hollow');

    // Render check: hollow = 2px orange ring over a dark centre; done =
    // filled electrolyte; both from the ONE cell widget.
    await tester.pumpWidget(
      _frame(
        Row(children: [
          SizedBox(
            width: 52,
            child: KyleCalendarDayCell(
              day: 20,
              data: days[20]!,
            ),
          ),
          SizedBox(
            width: 52,
            child: KyleCalendarDayCell(day: 5, data: days[5]!),
          ),
        ]),
      ),
    );
    await tester.pump();
    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .toList();
    expect(
      decorations.any(
        (d) =>
            d.shape == BoxShape.circle &&
            d.color == AppColors.blackberry &&
            d.border != null &&
            d.border!.top.color == AppColors.orange &&
            d.border!.top.width == AppMaterials.calendarDotPlannedStroke,
      ),
      isTrue,
      reason: 'hollow orange ring, 2 px stroke, visibly dark centre',
    );
    expect(
      decorations.any(
        (d) => d.shape == BoxShape.circle && d.color == AppColors.electrolyte,
      ),
      isTrue,
      reason: 'filled electrolyte dot',
    );
  });

  // cs8_tint_binary (Q2: tint slot; binary v1)
  testWidgets('cs8_tint_binary: >=1 athlete log tints; engine-planned-only '
      'does NOT tint; binary (no intensity); day boundary = log_date',
      (tester) async {
    final month = DateTime(2026, 8, 1);
    final now = DateTime(2026, 8, 14);
    // Producer-shaped: log_date strings exactly as the meal-logging service
    // writes them. The 15th got one log; the 16th five — binary renders the
    // same. The 20th has ONLY an engine-planned workout (its fuel plan is
    // embedded in the activity, never a meal_log row) — not tinted.
    final days = assembleCalendarMonth(
      month: month,
      now: now,
      activities: [_activity(id: 'engine', planned: DateTime(2026, 8, 20, 7))],
      loggedDates: const {'2026-08-15', '2026-08-16'},
    );
    expect(days[15]?.tinted, isTrue);
    expect(days[16]?.tinted, isTrue);
    expect(days[20]?.tinted ?? false, isFalse,
        reason: 'a day with only engine-planned items must NOT tint');
    expect(days[20]?.dot, CalendarDotState.planned,
        reason: 'the planned dot still renders — the channels are independent');

    // Binary: both tinted days paint the identical decoration.
    await tester.pumpWidget(
      _frame(
        Row(children: [
          SizedBox(
            width: 52,
            child: KyleCalendarDayCell(day: 15, data: days[15]!),
          ),
          SizedBox(
            width: 52,
            child: KyleCalendarDayCell(day: 16, data: days[16]!),
          ),
        ]),
      ),
    );
    await tester.pump();
    final tints = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == AppMaterials.calendarTintFill)
        .toList();
    expect(tints.length, 2, reason: 'both days tint');
    expect(tints[0], equals(tints[1]),
        reason: 'binary v1 — no intensity scaling renders');

    // Day boundary follows log_date itself (the daily-macros day
    // definition) — a '2026-08-15' log tints the 15th regardless of any
    // eaten-at instant.
    expect(days[14], isNull, reason: 'no bleed into adjacent days');
  });

  // cs9_today_selected_treatment (ruling 2026-09-06 — export governs)
  testWidgets('cs9_today_selected_treatment: today FILLED, selected RING, '
      'selected==today filled', (tester) async {
    Widget cell({required bool today, required bool selected}) => SizedBox(
      width: 52,
      child: KyleCalendarDayCell(
        day: 31,
        data: const KyleCalendarDayData(),
        isToday: today,
        isSelected: selected,
      ),
    );

    await tester.pumpWidget(
      _frame(
        Row(children: [
          cell(today: true, selected: false),
          cell(today: false, selected: true),
          cell(today: true, selected: true),
        ]),
      ),
    );
    await tester.pump();

    final numberBoxes = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.borderRadius != null)
        .toList();
    final filled =
        numberBoxes.where((d) => d.color == AppColors.cream).toList();
    final ringed = numberBoxes
        .where(
          (d) =>
              d.color == null &&
              d.border != null &&
              d.border!.top.color == AppColors.cream &&
              d.border!.top.width == AppMaterials.calendarSelectedRingStroke,
        )
        .toList();
    expect(filled.length, 2,
        reason: 'today renders filled; selected==today keeps the fill');
    expect(ringed.length, 1,
        reason: 'a selected non-today day renders the 2 px cream ring');
  });
}
