import 'package:flutter/material.dart';
import '../../features/nutrition_plan/presentation/screens/current_plan_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _currentIndex = 0;
  
  List<Widget> get _screens => [
    const CurrentPlanScreen(), // CurrentPlanScreen shows the plan or empty state
    // const RecipesScreen(),
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
    // BottomNavigationBarItem(
    //   icon: Image.asset(
    //     'assets/icons/recipes.png',
    //     width: 24,
    //     height: 24,
    //   ),
    //   activeIcon: Image.asset(
    //     'assets/icons/activeRecipes.png',
    //     width: 24,
    //     height: 24,
    //   ),
    //   label: 'Recipes',
    // ),
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
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}