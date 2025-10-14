import 'package:flutter/material.dart';
import '../../features/calendar/presentation/screens/activities_list_screen.dart';
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
    const ActivitiesListScreen(), // PRIMARY TAB: Activities-first interface with calendar picker
    const SettingsScreen(),
  ];

  List<BottomNavigationBarItem> get _tabs => [
    BottomNavigationBarItem(
      icon: Icon(
        Icons.list_alt,
        size: 24,
        color: Colors.grey,
      ),
      activeIcon: Icon(
        Icons.list_alt,
        size: 24,
        color: AppTheme.primary900,
      ),
      label: 'Activities',
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
      backgroundColor: AppTheme.baseCream,
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