import 'package:flutter/material.dart';
import '../../features/nutrition_plan/presentation/screens/current_plan_screen.dart';
import '../../features/user_journal/presentation/screens/voice_memo_screen.dart';
import '../../features/carb_loading/presentation/screens/carb_loading_screen_simple.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
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
    const CurrentPlanScreen(), // CurrentPlanScreen shows the plan or empty state
    const VoiceMemoScreen(), // Workout notes/journal entries
    const CarbLoadingScreenSimple(), // Simplified carb loading plans
    const SettingsScreen(),
  ];

  List<BottomNavigationBarItem> get _tabs => [
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icons/plan.png',
        width: 32,
        height: 32,
      ),
      activeIcon: Image.asset(
        'assets/icons/activePlan.png',
        width: 32,
        height: 32,
      ),
      label: 'Plan',
    ),
    BottomNavigationBarItem(
      icon: Icon(
        Icons.notes,
        size: 24,
        color: Colors.grey,
      ),
      activeIcon: Icon(
        Icons.notes,
        size: 24,
        color: AppTheme.primary900, // Use primary900 instead of primaryColor
      ),
      label: 'Workout Notes',
    ),
    BottomNavigationBarItem(
      icon: Icon(
        Icons.local_fire_department,
        size: 24,
        color: Colors.grey,
      ),
      activeIcon: Icon(
        Icons.local_fire_department,
        size: 24,
        color: AppTheme.primary900,
      ),
      label: 'Carb Loading',
    ),
    BottomNavigationBarItem(
      icon: Image.asset(
        'assets/icons/settings.png',
        width: 24,
        height: 24,
      ),
      activeIcon: Image.asset(
        'assets/icons/activeSettings.png',
        width: 24,
        height: 24,
      ),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _tabs,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary900,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}