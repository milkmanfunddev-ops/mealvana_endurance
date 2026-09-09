import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../features/meal_planning/presentation/screens/food_screen.dart';
import '../../features/subscription/application/pro_gate.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/home_shell/presentation/home_shell_chrome.dart';
import '../../features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../core/guarded_navigation.dart';
import '../utils/responsive_breakpoints.dart';
import 'kyle_design/navigation/kyle_tab_bar.dart';
import 'sync_status_indicator.dart';

/// The `/main` shell — home-shell@v1, SWITCHED OVER (Xuan, 2026-09-06).
///
/// Tab 0 is the recomposed home surface: [MacroDashboardBody] under
/// [HomeShellChrome]'s glass date header + [KyleTabBar]. The old
/// FloatingActionButtonsBar and the ViewTabs + WeekStrip day-header block
/// are DELETED (macro-dashboard.md §home-shell recomposition; the BY MONTH
/// view is superseded by the calendar sheet).
///
/// Q4 (tab-bar.md): the Fuel Timeline destination carries the HOUSE glyph,
/// and no destination icon is a calendar glyph while the date header
/// renders one — the rail mirrors the same set.
class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key, this.initialTabIndex = 0, this.initialTabName});

  final int initialTabIndex;

  /// Tab by name ('food', 'events', 'learn', …) — resolved against the live
  /// tab list, so it survives the Food tab appearing/disappearing with the
  /// Pro status. Wins over [initialTabIndex].
  final String? initialTabName;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final name = widget.initialTabName;
    if (name == null) return;
    // Resolve once, after the first build computed the index getters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = switch (name) {
        'food' => _showFoodTab ? _foodTabIndex : -1,
        'coach' => kIsWeb ? _coachTabIndex : -1,
        'events' || 'notes' || 'workout-notes' => _eventsTabIndex,
        'learn' || 'survey' => _learnTabIndex,
        _ => 0,
      };
      if (index >= 0) setState(() => _currentIndex = index);
    });
  }

  // Tab indices (Activities + Nutrition merged into one Fuel Timeline tab):
  // FuelTimeline(0) -> Food(1, Pro) -> Coach(web) -> Events -> Learn.
  // Food exists only while Pro is unlocked; every index after it shifts.
  bool get _showFoodTab => ref.watch(proUnlockedProvider);
  int get _foodTabIndex => 1;
  int get _coachTabIndex => _showFoodTab ? 2 : 1; // Only on web
  int get _eventsTabIndex => kIsWeb ? (_showFoodTab ? 3 : 2) : (_showFoodTab ? 2 : 1);
  int get _learnTabIndex => kIsWeb ? (_showFoodTab ? 4 : 3) : (_showFoodTab ? 3 : 2);

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  /// The shell's destination set (Q3: 3–5 — 4 on device with the Pro Food
  /// tab, 5 on web with the coach).
  List<KyleTabBarDestination> get _destinations => [
    KyleTabBarDestination(
      id: 'timeline',
      icon: FontAwesomeIcons.solidHouse.data,
      label: 'Timeline',
    ),
    if (_showFoodTab)
      KyleTabBarDestination(
        id: 'food',
        icon: FontAwesomeIcons.bowlFood.data,
        label: 'Food',
      ),
    if (kIsWeb)
      KyleTabBarDestination(
        id: 'coach',
        icon: FontAwesomeIcons.userTie.data,
        label: 'Coach',
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

  String get _activeTabId => _currentIndex == 0
      ? 'timeline'
      : _showFoodTab && _currentIndex == _foodTabIndex
      ? 'food'
      : kIsWeb && _currentIndex == _coachTabIndex
      ? 'coach'
      : _currentIndex == _eventsTabIndex
      ? 'events'
      : 'learn';

  void _onSelectTabId(String id) => _onTabSelected(switch (id) {
    'timeline' => 0,
    'food' => _foodTabIndex,
    'coach' => _coachTabIndex,
    'events' => _eventsTabIndex,
    _ => _learnTabIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showCoachTab = kIsWeb;
    final showFoodTab = _showFoodTab;
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

    // Tab 0 is the recomposed home: the dashboard's day content, running
    // full-height under the chrome — its pinned instrument block includes
    // the header clearance so the dissolve spans from the surface top
    // (ruling #4). The Food tab (meal planning, Pro) sits right after it
    // while unlocked; every index after it shifts.
    final screens = [
      Container(
        color: isDark ? AppColors.blackberry : AppColors.cream,
        child: const MacroDashboardBody(
          topInset: HomeShellChrome.headerClearancePx,
          bottomInset: HomeShellChrome.bottomChromeClearancePx,
        ),
      ),
      if (showFoodTab) const FoodScreen(), // 1: Food (Pro)
      if (showCoachTab)
        const SizedBox.shrink(), // placeholder (coach portal rendered above)
      const EventsListScreen(),
      const EducationScreen(),
    ];

    // Adjust current index if it's out of bounds (safety check)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final body = Column(
      children: [
        const SyncStatusIndicator(),
        Expanded(
          child: HomeShellChrome(
            body: IndexedStack(index: _currentIndex, children: screens),
            destinations: _destinations,
            activeTabId: _activeTabId,
            onSelectTab: _onSelectTabId,
            showDateHeader: _currentIndex == 0,
            showTabBar: !useRail,
          ),
        ),
      ],
    );

    final settingsGear = Positioned(
      top: MediaQuery.of(context).padding.top,
      right: 4,
      child: IconButton(
        key: const ValueKey('calendar.settings_button'),
        onPressed: () => context.pushOnce('/settings'),
        tooltip: 'Settings',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: FaIcon(
          FontAwesomeIcons.gear,
          size: 22,
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
      ),
    );

    if (useRail) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        body: Row(
          children: [
            _NavigationRailSection(
              currentIndex: _currentIndex,
              showCoachTab: showCoachTab,
              showFoodTab: showFoodTab,
              onTabSelected: _onTabSelected,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Stack(
                children: [
                  body,
                  // The home tab's gear lives in the shell's date header.
                  if (_currentIndex != 0) settingsGear,
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout — the shell's floating glass tab bar
    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(preferredSize: Size.zero, child: Container()),
      body: Stack(
        children: [
          body,
          if (_currentIndex != 0) settingsGear,
        ],
      ),
    );
  }
}

/// NavigationRail sidebar for wide screens.
///
/// Mirrors the [KyleTabBar] destination set (tab-bar.md Q4: house glyph on
/// the home item; no calendar glyphs on the shell).
class _NavigationRailSection extends StatelessWidget {
  const _NavigationRailSection({
    required this.currentIndex,
    required this.showCoachTab,
    required this.showFoodTab,
    required this.onTabSelected,
  });

  final int currentIndex;
  final bool showCoachTab;
  final bool showFoodTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build destinations list — same order as tab indices.
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.solidHouse),
        selectedIcon: FaIcon(FontAwesomeIcons.solidHouse),
        label: Text('Timeline'),
      ),
      if (showFoodTab)
        const NavigationRailDestination(
          icon: FaIcon(FontAwesomeIcons.bowlFood),
          selectedIcon: FaIcon(FontAwesomeIcons.bowlFood),
          label: Text('Food'),
        ),
      if (showCoachTab)
        const NavigationRailDestination(
          icon: FaIcon(FontAwesomeIcons.userTie),
          selectedIcon: FaIcon(FontAwesomeIcons.userTie),
          label: Text('Coach'),
        ),
      const NavigationRailDestination(
        icon: FaIcon(FontAwesomeIcons.trophy),
        selectedIcon: FaIcon(FontAwesomeIcons.trophy),
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
