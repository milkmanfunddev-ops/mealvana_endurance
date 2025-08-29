import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';

// Import all screens
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/user_profile_screen.dart';
import '../../features/onboarding/presentation/screens/food_preferences_screen.dart';
import '../../features/nutrition_plan/presentation/screens/current_plan_screen.dart';
import '../../features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import '../../features/nutrition_plan/presentation/screens/swap_food_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_edit_screen.dart';
import '../widgets/tabs_screen.dart';

/// Central router configuration for the Mealvana Endurance app
class AppRouter {
  // Static router instance - no Ref dependency
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    // Clean router with no startup logic - just handles routing
    redirect: (context, state) {
      // No redirect logic needed - AppStartupWidget will handle initial navigation
      return null;
    },
      routes: [
      // Root - AppStartupWidget handles initialization and navigation
      GoRoute(
        path: '/',
        builder: (context, state) => const AppStartupWidget(),
      ),
      
      // Welcome Screen
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      
      // Onboarding Flow
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        redirect: (context, state) => '/onboarding/profile',
      ),
      
      GoRoute(
        path: '/onboarding/profile',
        name: 'onboarding-profile',
        builder: (context, state) => const UserProfileScreen(),
      ),
      
      GoRoute(
        path: '/onboarding/food-preferences',
        name: 'onboarding-food-preferences', 
        builder: (context, state) => const FoodPreferencesScreen(),
      ),
      GoRoute(
        path: '/distancepacegut',
        name: 'distancepacegut', 
        builder: (context, state) => const DistancePaceGutEntryScreen(),
      ),
      // Main tabs screen (after onboarding)
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const TabsScreen(),
      ),
      
      // Current Plan Screen - Shows generated nutrition plan or empty state
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (context, state) => const CurrentPlanScreen(),
      ),
      
      // Current Plan Screen alias - for navigation from adjust macros
      GoRoute(
        path: '/current-plan',
        name: 'current-plan',
        builder: (context, state) => const CurrentPlanScreen(),
      ),
      
      // Adjust Macros Screen - Fine-tune macro targets before generating plan
      GoRoute(
        path: '/adjust-macros',
        name: 'adjust-macros',
        builder: (context, state) => const AdjustMacrosScreen(),
      ),
      
      // Settings Screen - User profile and preferences
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      
      // Food Preferences Edit Screen - Edit food preferences from settings
      GoRoute(
        path: '/settings/food-preferences',
        name: 'settings-food-preferences',
        builder: (context, state) => const FoodPreferencesEditScreen(),
      ),
      
      // Swap/Add Food Screen - Add or swap foods in nutrition plan
      GoRoute(
        path: '/swap-food',
        name: 'swap-food',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SwapFoodScreen(
            foodToSwapId: extra?['foodToSwapId'] as String?,
            foodToSwapName: extra?['foodToSwapName'] as String?,
            category: extra?['category'] as String? ?? 'before_run',
          );
        },
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you\'re looking for doesn\'t exist.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/welcome'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    );
}