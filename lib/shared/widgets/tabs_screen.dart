import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../features/fuel_timeline/presentation/screens/fuel_timeline_screen.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../core/guarded_navigation.dart';
import '../utils/responsive_breakpoints.dart';
import 'kyle_design/navigation/floating_action_buttons_bar.dart';
import 'sync_status_indicator.dart';

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  // Tab indices (Activities + Nutrition merged into one Fuel Timeline tab):
  // FuelTimeline(0) -> Coach(1, web only) -> Events(1 or 2) -> Learn(2 or 3)
  int get _coachTabIndex => 1; // Only on web
  int get _eventsTabIndex => kIsWeb ? 2 : 1;
  int get _learnTabIndex => kIsWeb ? 3 : 2;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showCoachTab = kIsWeb;
    final useRail = context.useNavigationRail;

    // Navigate to coach portal route when coach tab is selected on web
    if (showCoachTab && _currentIndex == _coachTabIndex) {
      // Reset to calendar tab and navigate to the coach portal route
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = 0);
          context.go('/coach-portal');
        }
      });
    }

    // Build the list of screens dynamically. Activities + Nutrition are merged
    // into the single Fuel Timeline tab.
    final screens = [
      const FuelTimelineScreen(), // 0: Fuel Timeline (day + food + workouts)
      if (showCoachTab)
        const SizedBox.shrink(), // 1: placeholder (coach portal rendered above)
      const EventsListScreen(), // 1 or 2: Events
      const EducationScreen(), // 2 or 3: Learn
    ];

    // Adjust current index if it's out of bounds (safety check)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final body = Column(
      children: [
        const SyncStatusIndicator(),
        Expanded(
          child: IndexedStack(index: _currentIndex, children: screens),
        ),
      ],
    );

    if (useRail) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        body: Row(
          children: [
            _NavigationRailSection(
              currentIndex: _currentIndex,
              showCoachTab: showCoachTab,
              onTabSelected: _onTabSelected,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Stack(
                children: [
                  body,
                  if (_currentIndex != 0)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: GestureDetector(
                        key: const ValueKey('calendar.settings_button'),
                        onTap: () => context.pushOnce('/settings'),
                        child: FaIcon(
                          FontAwesomeIcons.gear,
                          size: 18,
                          color: isDark
                              ? AppColors.cream
                              : AppColors.blackberry,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout — floating pill navigation
    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(preferredSize: Size.zero, child: Container()),
      body: Stack(
        children: [
          body,
          // Settings gear — top-right. The Fuel Timeline tab (0) draws its own
          // gear in its header, so skip it there to avoid a duplicate.
          if (_currentIndex != 0)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              right: 4,
              child: Semantics(
                button: true,
                label: 'Settings',
                child: GestureDetector(
                  key: const ValueKey('calendar.settings_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.pushOnce('/settings'),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: FaIcon(
                      FontAwesomeIcons.gear,
                      size: 18,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                ),
              ),
            ),
          FloatingActionButtonsBar(
            activeButton: _currentIndex,
            showCoachTab: showCoachTab,
            onTimelineTap: () => _onTabSelected(0),
            onCoachTap: () => _onTabSelected(_coachTabIndex),
            onEventsTap: () => _onTabSelected(_eventsTabIndex),
            onLearnTap: () => _onTabSelected(_learnTabIndex),
          ),
        ],
      ),
    );
  }
}

/// NavigationRail sidebar for wide screens.
///
/// Shows the same destinations as [FloatingActionButtonsBar] with
/// an orange FAB at the bottom for adding new activities.
class _NavigationRailSection extends StatelessWidget {
  const _NavigationRailSection({
    required this.currentIndex,
    required this.showCoachTab,
    required this.onTabSelected,
  });

  final int currentIndex;
  final bool showCoachTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build destinations list — same order as tab indices.
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.calendar),
        selectedIcon: FaIcon(FontAwesomeIcons.solidCalendar),
        label: Text('Today'),
      ),
      if (showCoachTab)
        const NavigationRailDestination(
          icon: FaIcon(FontAwesomeIcons.userTie),
          selectedIcon: FaIcon(FontAwesomeIcons.userTie),
          label: Text('Coach'),
        ),
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.calendarCheck),
        selectedIcon: FaIcon(FontAwesomeIcons.solidCalendarCheck),
        label: Text('Events'),
      ),
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.graduationCap),
        selectedIcon: FaIcon(FontAwesomeIcons.graduationCap),
        label: Text('Learn'),
      ),
    ];

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTabSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: isDark ? AppColors.blackberryDark : AppColors.cream,
      selectedIconTheme: IconThemeData(color: AppColors.orange, size: 20),
      unselectedIconTheme: IconThemeData(
        color: isDark ? AppColors.cream : AppColors.blackberry,
        size: 20,
      ),
      selectedLabelTextStyle: TextStyle(
        color: AppColors.orange,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: isDark ? AppColors.cream : AppColors.blackberry,
        fontSize: 11,
      ),
      indicatorColor: AppColors.orange.withValues(alpha: 0.15),
      destinations: destinations,
    );
  }
}
