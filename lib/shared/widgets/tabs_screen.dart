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

  List<Widget> get _screens => [
    const ActivitiesListScreen(), // PRIMARY TAB: Activities-first interface with calendar picker
    const FeatureSurveyScreen(), // Feature survey tab
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: Container(),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          FloatingActionButtonsBar(
            activeButton: _currentIndex,
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
            onSurveyTap: () {
              setState(() {
                _currentIndex = 1; // Navigate to Survey
              });
            },
            onMenuTap: () {
              setState(() {
                _currentIndex = 2; // Navigate to Settings
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
