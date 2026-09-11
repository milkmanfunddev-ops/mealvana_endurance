/// The home shell chrome — `home-shell@v1`, SWITCHED OVER (Xuan, 2026-09-06:
/// switchover ships with the bundle; the staged new-screen fence is lifted
/// and the old chrome is deleted).
///
/// Surface contract: docs/ssot/spec/design/surfaces/macro-dashboard.md
/// §home-shell recomposition — effective on `/main` itself:
///  * [KyleDateHeader] + [KyleTabBar] + [KyleCalendarSheet] (via
///    [showHomeShellCalendarSheet]) compose the shell — materials per
///    tokens.md §Materials.
///  * The ViewTabs + WeekStrip block is GONE (deleted with
///    fuel_timeline_day_header.dart); the BY MONTH view is superseded by
///    the calendar sheet.
///  * Adjacent-day navigation is the date header's chevrons; there is NO
///    screen-level horizontal swipe over the timeline (dh5).
///  * The tab bar is left-anchored with the named EMPTY bottom-right
///    utility slot (tab-bar.md Q2).
///
/// Composition: [TabsScreen] mounts this around its tab stack — [body] is
/// the active tab's content, [onSelectTab] drives the real tab switch, and
/// the date header renders only while the Fuel Timeline tab is active
/// ([showDateHeader]). Wide screens keep the NavigationRail and pass
/// [showTabBar] false.
///
/// Scroll thresholds (pinned in `home-shell.gestures.yaml`, never prose):
/// the bar collapses past [tabBarCollapseThresholdPx] and re-expands below
/// [tabBarExpandThresholdPx] (hysteresis = the band between them); the
/// header compacts past [headerCompactThresholdPx].
///
/// The bar also retracts while the Vana launcher's pill shows (vana-moment
/// spec, PILL), so the two never overlap; it comes back when the pill goes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/core/guarded_navigation.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_date_header.dart';
import '../../../shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';
import '../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../meal_planning/application/vana_moment_controller.dart';
import 'widgets/home_shell_calendar_host.dart';

class HomeShellChrome extends ConsumerStatefulWidget {
  const HomeShellChrome({
    super.key,
    required this.body,
    required this.destinations,
    required this.activeTabId,
    required this.onSelectTab,
    this.showDateHeader = true,
    this.showTabBar = true,
    this.now,
  });

  /// The active tab's content (the tab stack); scroll notifications
  /// bubbling out of it drive the bar collapse and header compaction.
  final Widget body;

  final List<KyleTabBarDestination> destinations;
  final String activeTabId;
  final ValueChanged<String> onSelectTab;

  /// The date header belongs to the home surface — false on other tabs.
  final bool showDateHeader;

  /// False on wide screens, where the NavigationRail is the navigation.
  final bool showTabBar;

  /// Injectable wall clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  // ---- pinned scroll thresholds (home-shell.gestures.yaml tb1/tb2) ----
  static const double tabBarCollapseThresholdPx = 88.0;
  static const double tabBarExpandThresholdPx = 64.0;

  /// Space the overlaid REST header needs above the timeline content — the
  /// home tab's body applies it (see [TabsScreen]).
  static const double headerClearancePx = 56.0;

  @override
  ConsumerState<HomeShellChrome> createState() => _HomeShellChromeState();
}

class _HomeShellChromeState extends ConsumerState<HomeShellChrome> {
  bool _tabBarCollapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final px = notification.metrics.pixels;
    setState(() {
      // Hysteresis band (tb2): between the two thresholds the bar keeps its
      // state, so dithering at the boundary never flaps it.
      if (px > HomeShellChrome.tabBarCollapseThresholdPx) {
        _tabBarCollapsed = true;
      } else if (px < HomeShellChrome.tabBarExpandThresholdPx) {
        _tabBarCollapsed = false;
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    // The launcher's pill borrows the bar's retract while it speaks.
    final pillShows =
        ref.watch(vanaMomentControllerProvider).value?.pillShows ?? false;
    final media = MediaQuery.of(context);
    // Q2 geometry: the expanded pill may grow up to the utility slot's
    // clearance, never into it.
    final barMaxWidth =
        media.size.width -
        14 - // left margin (anchor)
        KyleTabBar.utilitySlotGap -
        KyleTabBar.utilitySlotSize -
        14; // right margin

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Tab content — scrolls under the header and the bar.
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.body,
            ),
          ),
          // Date header — kept in the tree via Offstage (NOT a conditional
          // child: adding/removing it shifts the tab bar's element slot and
          // Flutter then recreates the bar's State — killing the travel
          // animation on every Timeline transition).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Offstage(
              offstage: !widget.showDateHeader,
              child: KyleDateHeader(
                date: selectedDate,
                // Ruling #4: the home pins its instrument block — the header
                // stays REST (COMPACT remains ratified at the component
                // level for compositions that scroll their header).
                compact: false,
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
          ),
          // Tab bar — left-anchored (Q2); the Vana launcher fills the
          // bottom-right utility slot from above the router.
          Positioned(
            left: 14,
            bottom: 28,
            child: Offstage(
              offstage: !widget.showTabBar,
              child: KyleTabBar(
                destinations: widget.destinations,
                activeId: widget.activeTabId,
                collapsed: _tabBarCollapsed || pillShows,
                maxWidth: barMaxWidth,
                onSelect: widget.onSelectTab,
                onCollapsedTap: () => setState(() => _tabBarCollapsed = false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
