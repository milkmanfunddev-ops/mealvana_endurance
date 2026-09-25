import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../features/meal_planning/presentation/screens/food_screen.dart';
import '../../features/meal_planning/domain/vana_situation.dart';
import '../../features/meal_planning/presentation/widgets/vana_situation_scope.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/content/application/content_service.dart';
import '../../features/content/domain/content_keys.dart';
import '../../features/home_shell/presentation/home_shell_chrome.dart';
import '../../features/integrations/presentation/providers/integrations_providers.dart';
import '../services/preferences_service.dart';
import '../services/whats_new_gate.dart';
import 'whats_new_sheet.dart';
import '../../features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../core/guarded_navigation.dart';
import '../utils/responsive_breakpoints.dart';
import 'kyle_design/navigation/kyle_tab_bar.dart';
import 'lazy_indexed_stack.dart';
import 'sync_status_indicator.dart';
import '../providers/user_id_provider.dart';
import 'kyle_design/sheets/tp_writeback_consent_sheet.dart';

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
  const TabsScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialTabName,
    this.initialFoodTab = FoodTab.plan,
    this.request,
  });

  final int initialTabIndex;

  /// Tab by name ('food', 'events', 'learn', …) — resolved against the live
  /// tab list, so it survives the Food tab appearing/disappearing with the
  /// Pro status. Wins over [initialTabIndex].
  final String? initialTabName;

  /// Which segment the Food tab opens on (`/main?tab=food&food=shopping`).
  final FoodTab initialFoodTab;

  /// The route's `extra`, fresh on every navigation that names a tab
  /// ([foodTabRequest]), so asking again for the same tab still selects it.
  final Object? request;

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWhatsNew());
    }
  }

  /// Once per announcement version (content `whats_new.version`), on the
  /// first launch after an install or update: the glass "What's new" sheet.
  /// Shake-to-report is what it announces today; the copy is content-managed.
  Future<void> _maybeShowWhatsNew() async {
    final announced = ref
        .read(contentServiceProvider)
        .getValue(ContentKeys.whatsNewVersion, defaultValue: '');
    final prefs = ref.read(preferencesServiceProvider);
    final info = await ref.read(packageInfoProvider.future);
    if (!mounted) return;
    final show = shouldShowWhatsNew(
      appVersion: info.version,
      announcementVersion: announced,
      lastShownVersion: prefs.whatsNewShownVersion,
    );
    if (!show) return;
    // Record first so a crash mid-sheet never turns it into a nag.
    await prefs.markWhatsNewShown(announced);
    if (!mounted) return;
    await showWhatsNewSheet(context);
    // DI-10 migration notice (Q-INT16 amended to opt-out, 2026-09-11):
    // athletes who were ALREADY pushing before the amendment get the same
    // opt-out notice exactly once, on first launch after the update. No
    // one's push flow stops — sharing stays on unless they turn it off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowWritebackMigrationNotice();
    });
  }

  Future<void> _maybeShowWritebackMigrationNotice() async {
    if (!mounted) return;
    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.tpWritebackNoticeShown) return;
    if (prefs.tpWritebackPremiumBlocked) return;
    try {
      final userId = await ref.read(userIdProvider.future);
      final integrationsRepo = ref.read(integrationsRepositoryProvider);
      final tp = await integrationsRepo.getIntegration(
        userId,
        'training_peaks',
      );
      // Ticket 64: a connection TP refused to refresh is not working; the
      // sharing notice would read as if it were. It shows after a reconnect.
      if (tp == null || !tp.isActive || tp.needsReconnect) return;
      await prefs.ensureTpWritebackDefaultExplicit();
      if (!mounted) return;
      final choice = await TpWritebackConsentSheet.show(context);
      if (choice == false) {
        await prefs.setTpWritebackEnabled(false);
      }
      await prefs.setTpWritebackNoticeShown(true);
    } catch (_) {
      // Never let the notice break the shell; it retries next launch
      // because the notice-shown flag was not set.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectNamedTab();
  }

  // Going to `/main?tab=…` while the shell is already up reuses this state;
  // a newly named tab or Food segment must still be selected (mp-596).
  @override
  void didUpdateWidget(TabsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabName != oldWidget.initialTabName ||
        widget.initialFoodTab != oldWidget.initialFoodTab ||
        widget.request != oldWidget.request) {
      _selectNamedTab();
    }
  }

  void _selectNamedTab() {
    final name = widget.initialTabName;
    if (name == null) return;
    // Resolve after the build computed the index getters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = switch (name) {
        'food' => _foodTabIndex,
        'coach' => kIsWeb ? _coachTabIndex : -1,
        'events' || 'notes' || 'workout-notes' => _eventsTabIndex,
        'learn' || 'survey' => _learnTabIndex,
        _ => 0,
      };
      if (index >= 0) setState(() => _currentIndex = index);
    });
  }

  // Tab indices (Activities + Nutrition merged into one Fuel Timeline tab):
  // FuelTimeline(0) -> Food(1) -> Coach(web) -> Events -> Learn.
  // The whole app sits behind the one gate (mp-280), so the Food tab is
  // always present; only the web coach tab shifts the indices.
  int get _foodTabIndex => 1;
  int get _coachTabIndex => 2; // Only on web
  int get _eventsTabIndex => kIsWeb ? 3 : 2;
  int get _learnTabIndex => kIsWeb ? 4 : 3;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  /// The shell's destination set (Q3: 3–5 — 4 on device, 5 on web with the
  /// coach).
  List<KyleTabBarDestination> get _destinations => [
    KyleTabBarDestination(
      id: 'timeline',
      icon: FontAwesomeIcons.solidHouse.data,
      label: 'Timeline',
    ),
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
      : _currentIndex == _foodTabIndex
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
    //
    // Each tab is built the first time it is selected and kept alive after
    // (LazyIndexedStack). Building all of them up front meant every launch
    // fired the Food tabs' `vana-action` calls, including launches that never
    // left the Timeline (mp-432, approved as mp-468).
    final screenBuilders = <Widget Function()>[
      () => Container(
        color: isDark ? AppColors.blackberry : AppColors.cream,
        child: const MacroDashboardBody(
          topInset: HomeShellChrome.headerClearancePx,
          bottomInset: HomeShellChrome.bottomChromeClearancePx,
        ),
      ),
      () => FoodScreen(
        initialTab: widget.initialFoodTab,
        request: widget.request,
      ), // 1: Food
      if (showCoachTab)
        () => const SizedBox.shrink(), // coach portal is rendered above
      () => const EventsListScreen(
        bottomInset: HomeShellChrome.bottomChromeClearancePx,
      ),
      () => const EducationScreen(),
    ];

    // Adjust current index if it's out of bounds (safety check)
    if (_currentIndex >= screenBuilders.length) {
      _currentIndex = 0;
    }

    // The shell speaks for every tab: the day on the Fuel Timeline, the tab's
    // route elsewhere. A tab with a scope of its own (Food, Events) reports
    // after the shell and overrides it; one without (Learn) is still not
    // spoken for by the tab before it.
    final shellSituation = VanaSituation.shellTab(_activeTabId, DateTime.now());

    final body = Column(
      children: [
        const SyncStatusIndicator(),
        Expanded(
          child: HomeShellChrome(
            body: LazyIndexedStack(
              index: _currentIndex,
              itemCount: screenBuilders.length,
              // A visited tab stays built; only one is on screen. Without the
              // visibility wrapper each offscreen tab reports its Situation
              // too, and the last one wins.
              itemBuilder: (_, i) => VanaSituationVisibility(
                visible: i == _currentIndex,
                child: screenBuilders[i](),
              ),
            ),
            destinations: _destinations,
            activeTabId: _activeTabId,
            onSelectTab: _onSelectTabId,
            showDateHeader: _currentIndex == 0,
            showTabBar: !useRail,
            request: widget.request,
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
      return VanaSituationScope(
        situation: shellSituation,
        child: Scaffold(
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
                    // The home tab's gear lives in the shell's date header.
                    if (_currentIndex != 0) settingsGear,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile layout — the shell's floating glass tab bar
    return VanaSituationScope(
      situation: shellSituation,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(preferredSize: Size.zero, child: Container()),
        body: Stack(children: [body, if (_currentIndex != 0) settingsGear]),
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
        icon: FaIcon(FontAwesomeIcons.solidHouse),
        selectedIcon: FaIcon(FontAwesomeIcons.solidHouse),
        label: Text('Timeline'),
      ),
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
