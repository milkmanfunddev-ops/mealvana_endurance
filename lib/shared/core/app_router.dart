import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';

// Import all screens
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/onboarding/presentation/screens/user_profile_screen.dart';
import '../../features/onboarding/presentation/screens/food_preferences_screen.dart';
import '../../features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import '../../features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import '../../features/nutrition_plan/presentation/screens/swap_food_screen.dart';
import '../../features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_edit_screen.dart';
import '../../features/barcode_scanning/presentation/screens/add_food_screen.dart';
import '../../features/feedback/presentation/screens/survey_screen.dart';
import '../../features/user_journal/presentation/screens/plan_how_well_screen.dart';
import '../../features/user_journal/presentation/screens/voice_notes_list_screen.dart';
import '../../features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart';
import '../../features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart';
import '../../features/carb_loading/domain/meal_type.dart';
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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DistancePaceGutEntryScreen(
            initialDate: extra?['initialDate'] as DateTime?,
            initialDistance: extra?['distance'] as double?,
            initialGoalPace: extra?['goalPace'] as double?,
            activityId: extra?['activityId'] as String?,
            eventId: extra?['eventId'] as String?,
          );
        },
      ),

      // Alias for distance-pace-gut-entry (for consistency)
      GoRoute(
        path: '/distance-pace-gut-entry',
        name: 'distance-pace-gut-entry',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DistancePaceGutEntryScreen(
            initialDate: extra?['initialDate'] as DateTime?,
            initialDistance: extra?['distance'] as double?,
            initialGoalPace: extra?['goalPace'] as double?,
            activityId: extra?['activityId'] as String?,
            eventId: extra?['eventId'] as String?,
          );
        },
      ),
      // Main tabs screen (after onboarding)
      GoRoute(
        path: '/main',
        name: 'main',
        builder: (context, state) {
          // Support tab query parameter to navigate to specific tab
          final tabParam = state.uri.queryParameters['tab'];
          int initialTab = 0;
          
          switch (tabParam) {
            case 'notes':
            case 'workout-notes':
              initialTab = 1;
              break;
            case 'settings':
              initialTab = 2;
              break;
            default:
              initialTab = 0;
          }
          
          return TabsScreen(initialTabIndex: initialTab);
        },
      ),
      
      // Survey screen - shown after plan generation
      GoRoute(
        path: '/survey',
        name: 'survey',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SurveyScreen(
            planName: extra?['planName'] as String?,
          );
        },
      ),
      
      // Activity Detail Screen - Shows nutrition plan and activity details
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ActivityDetailScreen(
            mode: extra?['mode'] ?? 'view',
            activityId: extra?['activityId'],
            pendingActivityData: extra?['pendingActivityData'],
            macroTargets: extra?['macroTargets'],
          );
        },
      ),

      // Activity Detail Screen alias - for navigation from adjust macros
      GoRoute(
        path: '/current-plan',
        name: 'current-plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ActivityDetailScreen(
            mode: extra?['mode'] ?? 'view',
            activityId: extra?['activityId'],
            pendingActivityData: extra?['pendingActivityData'],
            macroTargets: extra?['macroTargets'],
          );
        },
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

      // Add Food Screen - Add foods from settings food preferences
      GoRoute(
        path: '/settings/food-preferences/add-food',
        name: 'settings-add-food',
        builder: (context, state) => const AddFoodScreen(),
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

      // Barcode Scanner Screen - Scan barcodes to add/swap foods
      GoRoute(
        path: '/barcode-scanner',
        name: 'barcode-scanner',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BarcodeScannerScreen(
            category: extra?['category'] as String? ?? 'before_run',
            foodToSwapId: extra?['foodToSwapId'] as String?,
            foodToSwapName: extra?['foodToSwapName'] as String?,
          );
        },
      ),

      // Carb Loading Food Selection Screen - Select foods for carb loading meals
      GoRoute(
        path: '/carb-loading-select-food',
        name: 'carb-loading-select-food',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CarbLoadingFoodSelectionScreen(
            dayId: extra?['dayId'] as String,
            mealType: extra?['mealType'] as MealType,
          );
        },
      ),

      // Create Custom Carb Loading Food Screen - Manual food entry
      GoRoute(
        path: '/create-custom-carb-loading-food',
        name: 'create-custom-carb-loading-food',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateCustomCarbLoadingFoodScreen(
            dayId: extra?['dayId'] as String,
            mealType: extra?['mealType'] as MealType,
          );
        },
      ),

      // User Journal Routes
      
      // Plan Rating Screen - Rate how well a nutrition plan worked
      GoRoute(
        path: '/plan-how-well/:planId',
        name: 'plan-how-well',
        builder: (context, state) {
          final planId = state.pathParameters['planId']!;
          return PlanHowWellScreen(planId: planId);
        },
      ),
      
      // Voice Notes List Screen - View all saved notes
      GoRoute(
        path: '/voice-notes',
        name: 'voice-notes',
        builder: (context, state) => const VoiceNotesListScreen(),
      ),
      
      // Voice Memo Screen - Redirect to workout notes tab
      // Keeping for backward compatibility but redirects to tabs
      GoRoute(
        path: '/voice-memo/:planId',
        name: 'voice-memo',
        redirect: (context, state) {
          // Redirect to main tabs with notes tab selected
          return '/main?tab=workout-notes';
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