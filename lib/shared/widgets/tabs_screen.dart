import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/activities/presentation/screens/activities_list_screen.dart';
import '../../features/calendar/presentation/providers/calendar_view_provider.dart';
import '../../features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
import '../../features/coach_mode/presentation/screens/coach_portal_screen.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
import 'kyle_design/navigation/floating_action_buttons_bar.dart';
import 'responsive_content_wrapper.dart' show coachPortalActiveNotifier;
import 'sync_status_indicator.dart';

class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

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
    _syncCoachPortalNotifier();

    // On web, auto-navigate to coach portal if user is a coach
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoNavigateToCoachIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    // Reset full-width mode when leaving tabs
    coachPortalActiveNotifier.value = false;
    super.dispose();
  }

  /// Keep the global full-width notifier in sync with the current tab.
  void _syncCoachPortalNotifier() {
    coachPortalActiveNotifier.value = kIsWeb && _currentIndex == 1;
  }

  Future<void> _autoNavigateToCoachIfNeeded() async {
    // Skip if already on coach tab (e.g. from ?tab=coach query param)
    if (_currentIndex == 1) return;

    try {
      final dashboardAsync = await ref.read(
        coachDashboardControllerProvider.future,
      );
      if (!mounted) return;
      if (dashboardAsync.isCoach) {
        setState(() {
          _currentIndex = 1; // Coach tab
          _syncCoachPortalNotifier();
        });
      }
    } catch (_) {
      // Not a coach or network error — stay on activities tab
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show coach tab on web only (navigates to full-screen coach portal)
    final showCoachTab = kIsWeb;

    // Full-screen coach portal on web — bypasses IndexedStack, FAB, and
    // responsive max-width so the split-panel layout fills the viewport.
    if (showCoachTab && _currentIndex == 1) {
      return CoachPortalScreen(
        onBackToApp: () {
          setState(() {
            _currentIndex = 0;
            _syncCoachPortalNotifier();
          });
        },
      );
    }

    // Build the list of screens dynamically
    final screens = [
      const ActivitiesListScreen(), // 0: Activities (Calendar)
      if (showCoachTab)
        const SizedBox.shrink(), // 1: placeholder (coach portal rendered above)
      const EventsListScreen(), // 1 or 2: Events
      const EducationScreen(), // 2 or 3: Learn
      const SettingsScreen(), // 3 or 4: Settings
    ];

    // Adjust current index if it's out of bounds (safety check)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: Container(),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Background sync status indicator (shows when uploading to Supabase)
              const SyncStatusIndicator(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens,
                ),
              ),
            ],
          ),
          FloatingActionButtonsBar(
            activeButton: _currentIndex,
            showCoachTab: showCoachTab,
            onCalendarTap: () {
              // Navigate to Activities tab if not already there
              if (_currentIndex != 0) {
                setState(() {
                  _currentIndex = 0;
                  _syncCoachPortalNotifier();
                });
              } else {
                // Only toggle calendar view if already on Activities tab
                ref.read(calendarViewProvider.notifier).toggleView();
              }
            },
            onCoachTap: () {
              setState(() {
                _currentIndex = 1; // Coach tab (web only)
                _syncCoachPortalNotifier();
              });
            },
            onEventsTap: () {
              setState(() {
                // If coach tab is visible, Events is at index 2, otherwise 1
                _currentIndex = showCoachTab ? 2 : 1;
                _syncCoachPortalNotifier();
              });
            },
            onLearnTap: () {
              setState(() {
                // If coach tab is visible, Learn is at index 3, otherwise 2
                _currentIndex = showCoachTab ? 3 : 2;
                _syncCoachPortalNotifier();
              });
            },
            onMenuTap: () {
              setState(() {
                // If coach tab is visible, Settings is at index 4, otherwise 3
                _currentIndex = showCoachTab ? 4 : 3;
                _syncCoachPortalNotifier();
              });
            },
            onPlusTap: () {
              final selectedDate = ref.read(calendarSelectedDateProvider);
              context.pushNamed('distancepacegut', extra: {'initialDate': selectedDate});
            },
          ),
        ],
      ),
    );
  }
}
