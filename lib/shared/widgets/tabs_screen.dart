import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../features/activities/presentation/screens/activities_list_screen.dart';
import '../../features/calendar/presentation/providers/calendar_view_provider.dart';
import '../../features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../features/daily_macros/presentation/screens/daily_macros_screen.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
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

  // Tab indices (same on mobile and web now — coach portal is a separate route):
  // Calendar(0) -> Nutrition(1) -> Coach(2, web only) -> Events(2 or 3) -> Learn(3 or 4)
  int get _coachTabIndex => 2; // Only on web
  int get _eventsTabIndex => kIsWeb ? 3 : 2;
  int get _learnTabIndex => kIsWeb ? 4 : 3;

  void _onTabSelected(int index) {
    if (index == 0 && _currentIndex == 0) {
      // Toggle calendar view when already on Activities tab
      ref.read(calendarViewProvider.notifier).toggleView();
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _onPlusTap() {
    final selectedDate = ref.read(calendarSelectedDateProvider);
    context.pushNamed('distancepacegut', extra: {'initialDate': selectedDate});
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

    // Build the list of screens dynamically
    final screens = [
      const ActivitiesListScreen(), // 0: Activities (Calendar)
      const DailyMacrosScreen(), // 1: Nutrition Diary
      if (showCoachTab)
        const SizedBox.shrink(), // 2: placeholder (coach portal rendered above)
      const EventsListScreen(), // 2 or 3: Events
      const EducationScreen(), // 3 or 4: Learn
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
              onPlusTap: _onPlusTap,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Stack(
                children: [
                  body,
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 16,
                    child: GestureDetector(
                      key: const ValueKey('calendar.settings_button'),
                      onTap: () => context.push('/settings'),
                      child: FaIcon(
                        FontAwesomeIcons.gear,
                        size: 18,
                        color: isDark ? AppColors.cream : AppColors.blackberry,
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
          // Settings gear — top-right on every tab
          Positioned(
            top: MediaQuery.of(context).padding.top,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Settings',
              child: GestureDetector(
                key: const ValueKey('calendar.settings_button'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/settings'),
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
            onCalendarTap: () => _onTabSelected(0),
            onNutritionTap: () => _onTabSelected(1),
            onCoachTap: () => _onTabSelected(_coachTabIndex),
            onEventsTap: () => _onTabSelected(_eventsTabIndex),
            onLearnTap: () => _onTabSelected(_learnTabIndex),
            onPlusTap: _onPlusTap,
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
    required this.onPlusTap,
  });

  final int currentIndex;
  final bool showCoachTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onPlusTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build destinations list — same order as tab indices.
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.calendar),
        selectedIcon: FaIcon(FontAwesomeIcons.solidCalendar),
        label: Text('Calendar'),
      ),
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.utensils),
        selectedIcon: FaIcon(FontAwesomeIcons.utensils),
        label: Text('Nutrition'),
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
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FloatingActionButton(
              onPressed: onPlusTap,
              backgroundColor: AppColors.orange,
              child: const Icon(Icons.add, color: AppColors.cream),
            ),
          ),
        ),
      ),
      destinations: destinations,
    );
  }
}
