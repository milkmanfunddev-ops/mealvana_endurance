/// The NEW home shell — `home-shell@v1` (dev-visible; the shipped
/// [MacroDashboardScreen] home stays untouched until switchover).
///
/// Surface contract: docs/ssot/spec/design/surfaces/macro-dashboard.md
/// §home-shell recomposition (RULED Xuan 2026-09-06, staged — effective on
/// this screen only):
///  * [KyleDateHeader] + [KyleTabBar] + [KyleCalendarSheet] (via
///    [showHomeShellCalendarSheet]) join the composition — materials per
///    tokens.md §Materials.
///  * The ViewTabs + WeekStrip block ([FuelTimelineDayHeader]) leaves it;
///    the BY MONTH view is superseded on this surface by the calendar
///    sheet. The timeline content itself is the ONE dashboard body
///    ([MacroDashboardBody]).
///  * Adjacent-day navigation is the date header's chevrons; there is NO
///    screen-level horizontal swipe over the timeline (dh5 — the workout
///    card's G1–G4 set owns horizontal gestures there).
///  * The tab bar is left-anchored with the named EMPTY bottom-right
///    utility slot (tab-bar.md Q2); its future occupant inherits the FAB
///    clearance rule.
///
/// Scroll thresholds (pinned in `home-shell.gestures.yaml`, never prose):
/// tab bar collapses past [tabBarCollapseThresholdPx] and re-expands below
/// [tabBarExpandThresholdPx] (hysteresis = the band between them); the date
/// header compacts past [headerCompactThresholdPx].
///
/// Q4 (tab-bar.md): the Fuel Timeline destination carries the HOUSE glyph,
/// and no destination icon is a calendar glyph while the date header
/// renders one.
///
/// Reached in dev via the Debug screen (Settings → triple-tap → Home Shell
/// v2) — the registered-nowhere pattern; tab selection on other
/// destinations moves the highlight only (real tab content wires up at
/// switchover).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../shared/core/guarded_navigation.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_calendar_sheet.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_date_header.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';
import '../../../theme/kyle_design/app_colors.dart';
import '../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import 'widgets/home_shell_calendar_host.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key, this.now});

  /// Injectable wall clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  // ---- pinned scroll thresholds (home-shell.gestures.yaml tb1/tb2/dh3) ----
  static const double tabBarCollapseThresholdPx = 88.0;
  static const double tabBarExpandThresholdPx = 64.0;
  static const double headerCompactThresholdPx = 56.0;

  /// Space the overlaid REST header needs above the timeline content.
  static const double headerClearancePx = 56.0;

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  bool _tabBarCollapsed = false;
  bool _headerCompact = false;
  String _activeTab = 'timeline';

  static final _destinations = [
    // Q4: HOUSE glyph on Fuel Timeline; no calendar glyph anywhere on the
    // bar while the date header renders one (the shipped bar's calendar +
    // calendarCheck glyphs are retired on this shell).
    KyleTabBarDestination(
      id: 'timeline',
      icon: FontAwesomeIcons.house.data,
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
  ];

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final px = notification.metrics.pixels;
    setState(() {
      // Hysteresis band (tb2): between the two thresholds the bar keeps its
      // state, so dithering at the boundary never flaps it.
      if (px > HomeShellScreen.tabBarCollapseThresholdPx) {
        _tabBarCollapsed = true;
      } else if (px < HomeShellScreen.tabBarExpandThresholdPx) {
        _tabBarCollapsed = false;
      }
      _headerCompact = px > HomeShellScreen.headerCompactThresholdPx;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final media = MediaQuery.of(context);
    // Q2 geometry: the expanded pill may grow up to the utility slot's
    // clearance, never into it.
    final barMaxWidth =
        media.size.width -
        14 - // left margin (anchor)
        KyleTabBar.utilitySlotGap -
        KyleTabBar.utilitySlotSize -
        14; // right margin

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Timeline content — scrolls under the header and the bar.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: HomeShellScreen.headerClearancePx,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: const MacroDashboardBody(),
                ),
              ),
            ),
            // Date header — REST in the clearance band, COMPACT overlaying
            // scrolled content (the row itself takes the glass recipe).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: KyleDateHeader(
                date: selectedDate,
                compact: _headerCompact,
                now: widget.now,
                onSummonCalendar: () => showHomeShellCalendarSheet(context),
                onSettingsTap: () => context.pushOnce('/settings'),
                onPreviousDay: () => ref
                    .read(calendarSelectedDateProvider.notifier)
                    .setDate(selectedDate.subtract(const Duration(days: 1))),
                onNextDay: () => ref
                    .read(calendarSelectedDateProvider.notifier)
                    .setDate(selectedDate.add(const Duration(days: 1))),
              ),
            ),
            // Tab bar — left-anchored (Q2); the bottom-right utility slot
            // stays EMPTY in v1 (nothing composes there, deliberately).
            Positioned(
              left: 14,
              bottom: 16,
              child: KyleTabBar(
                destinations: _destinations,
                activeId: _activeTab,
                collapsed: _tabBarCollapsed,
                maxWidth: barMaxWidth,
                onSelect: (id) => setState(() => _activeTab = id),
                onCollapsedTap: () => setState(() => _tabBarCollapsed = false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
