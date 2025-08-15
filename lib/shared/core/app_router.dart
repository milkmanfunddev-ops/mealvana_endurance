import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Import all screens
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/user_profile_screen.dart';
import '../../features/onboarding/presentation/screens/food_preferences_screen.dart';
import '../../features/nutrition_plan/presentation/screens/main_nutrition_plan_screen.dart';
import '../../features/nutrition_plan/presentation/screens/plan_screen.dart';

/// Central router configuration for the Mealvana Endurance app
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Simple redirect logic - can be enhanced later with proper state management
      final location = state.matchedLocation;
      
      // Allow access to onboarding and welcome screens
      if (location.startsWith('/welcome') || 
          location.startsWith('/onboarding') ||
          location == '/') {
        return null;
      }
      
      // For now, allow access to all screens (MVP behavior)
      return null;
    },
    routes: [
      // Root redirect to welcome/onboarding first
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      
      // Main nutrition plan screen (after onboarding)
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) => const MainNutritionPlanScreen(),
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
      
      // Plan Screen - Shows generated nutrition plan
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (context, state) => const PlanScreen(),
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

/// Provider for router - useful for navigation in services
final routerProvider = Provider<GoRouter>((ref) => AppRouter.router);