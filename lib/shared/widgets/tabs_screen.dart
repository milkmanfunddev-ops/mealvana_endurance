import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/activities/presentation/screens/activities_list_screen.dart';
import '../../features/calendar/presentation/providers/calendar_view_provider.dart';
import '../../features/calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../features/feature_survey/presentation/screens/feature_survey_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../theme/kyle_design/app_colors.dart';
import 'kyle_design/navigation/floating_action_buttons_bar.dart';
import 'sync_status_indicator.dart';

import '../../features/coach_mode/presentation/screens/my_coaches_screen.dart';
import '../../features/coach_mode/presentation/providers/my_coaches_controller.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if user has active coaches to show the Coach tab
    final myCoachesState = ref.watch(myCoachesControllerProvider);
    final hasCoaches = myCoachesState.value?.hasCoaches ?? false;

    // Build the list of screens dynamically
    final screens = [
      const ActivitiesListScreen(), // 0: Activities (Calendar)
      if (hasCoaches) const MyCoachesScreen(), // 1: Coach (Conditional)
      const FeatureSurveyScreen(), // 1 or 2: Survey
      const SettingsScreen(), // 2 or 3: Settings
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
            showCoachTab: hasCoaches,
            onCalendarTap: () {
              // Navigate to Activities tab if not already there
              if (_currentIndex != 0) {
                setState(() {
                  _currentIndex = 0;
                });
              } else {
                // Only toggle calendar view if already on Activities tab
                ref.read(calendarViewProvider.notifier).toggleView();
              }
            },
            onCoachTap: () {
              setState(() {
                _currentIndex = 1; // Coach tab is always at index 1 if visible
              });
            },
            onSurveyTap: () {
              setState(() {
                // If coach tab is visible, Survey is at index 2, otherwise 1
                _currentIndex = hasCoaches ? 2 : 1;
              });
            },
            onMenuTap: () {
              setState(() {
                // If coach tab is visible, Settings is at index 3, otherwise 2
                _currentIndex = hasCoaches ? 3 : 2;
              });
            },
            onAddTap: () {
              // Navigate to New Activity Screen (Kyle's unified tabbed design)
              final selectedDate = ref.read(calendarSelectedDateProvider);
              context.pushNamed('distancepacegut', extra: {'initialDate': selectedDate});
            },
          ),
        ],
      ),
    );
  }
}
