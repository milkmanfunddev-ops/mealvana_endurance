import 'package:flutter/material.dart';
import '../../features/calendar/presentation/screens/activities_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/feature_survey/presentation/screens/feature_survey_screen.dart';
import '../../theme/app_theme.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
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

  List<_TabItem> get _tabs => [
    _TabItem(
      icon: Icons.list_alt,
      label: 'Activities',
    ),
    _TabItem(
      icon: Icons.assignment,
      label: 'Survey',
    ),
    _TabItem(
      icon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                final isSelected = _currentIndex == index;
                final tab = _tabs[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      color: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.icon,
                            size: 28,
                            color: isSelected ? AppTheme.primary900 : Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppTheme.primary900 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;

  _TabItem({
    required this.icon,
    required this.label,
  });
}
