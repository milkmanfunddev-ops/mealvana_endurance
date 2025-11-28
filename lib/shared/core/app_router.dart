import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/app_startup/application/app_startup_provider.dart';
import '../../main.dart' show sentryNavigatorKey;

// Import all screens
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/nutrition_plan/presentation/screens/new_activity_screen.dart';
import '../../features/onboarding/presentation/screens/user_profile_screen.dart';
import '../../features/onboarding/presentation/screens/sport_preferences_screen.dart';
import '../../features/onboarding/presentation/screens/food_preferences_screen.dart' as onboarding;
import '../../features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import '../../features/auth/presentation/screens/email_signup_screen.dart';
import '../../features/auth/presentation/screens/email_login_screen.dart';
import '../../features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import '../../features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/nutrition_plan/presentation/screens/swap_food_screen.dart';
import '../../features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart';
import '../../features/settings/presentation/screens/sport_settings_screen.dart';
import '../../features/settings/presentation/screens/preferences_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_screen.dart' as settings;
import '../../features/settings/presentation/screens/help_feedback_screen.dart';
import '../../features/barcode_scanning/presentation/screens/add_food_screen.dart';
import '../../features/user_journal/presentation/screens/plan_how_well_screen.dart';
import '../../features/user_journal/presentation/screens/voice_notes_list_screen.dart';
import '../../features/user_journal/presentation/screens/voice_memo_screen.dart';
import '../../features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart';
import '../../features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart';
import '../../features/carb_loading/domain/meal_type.dart';
import '../widgets/tabs_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/pro_version/presentation/screens/pro_version_screen.dart';

/// Central router configuration for the Mealvana Endurance app
/// Following Andrea Bizzotto's deep link pattern
class AppRouter {
  // Router provider with ref access for redirect logic
  static final routerProvider = Provider<GoRouter>((ref) {
    return GoRouter(
      initialLocation: '/',
      // Use Sentry navigator key for screenshot capture in feedback widget
      navigatorKey: sentryNavigatorKey,
      // Redirect logic based on app startup state
      redirect: (context, state) {
        // Allow navigation to any route - don't block
        // The initial '/' will be redirected based on app state
        if (state.uri.path != '/') {
          return null; // Allow navigation to specific routes
        }

        // For root path, check app startup state and redirect appropriately
        final appStartupState = ref.read(appStartupProvider);

        return appStartupState.maybeWhen(
          data: (appStartupData) {
            // User not created yet - go to welcome
            if (appStartupData.user == null) {
              return '/welcome';
            }
            // User exists but hasn't completed onboarding
            if (!appStartupData.hasCompletedOnboarding) {
              return '/onboarding/food-preferences';
            }
            // User has pending feedback to provide
            if (appStartupData.activityIdNeedingFeedback != null) {
              return '/plan-how-well/${appStartupData.activityIdNeedingFeedback}';
            }
            // User is fully onboarded - go to main app
            return '/main';
          },
          // While loading or on error, stay on root (AppStartupWidget handles UI)
          orElse: () => null,
        );
      },
      routes: [
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
        path: '/onboarding/sport-preferences',
        name: 'onboarding-sport-preferences',
        builder: (context, state) => const SportPreferencesScreen(),
      ),

      GoRoute(
        path: '/onboarding/food-preferences',
        name: 'onboarding-food-preferences',
        builder: (context, state) => const onboarding.FoodPreferencesScreen(),
      ),

      // Authentication Flow (Post-Onboarding)
      GoRoute(
        path: '/auth/post-onboarding',
        name: 'auth-post-onboarding',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'signup';
          return PostOnboardingAuthScreen(mode: mode);
        },
      ),

      GoRoute(
        path: '/auth/email-signup',
        name: 'auth-email-signup',
        builder: (context, state) => const EmailSignupScreen(),
      ),

      GoRoute(
        path: '/auth/email-login',
        name: 'auth-email-login',
        builder: (context, state) => const EmailLoginScreen(),
      ),

      // REDIRECTED: Old routes now point to NewActivityScreen (multi-sport Kyle design)
      GoRoute(
        path: '/distancepacegut',
        name: 'distancepacegut',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return NewActivityScreen(
            initialDate: extra?['initialDate'] as DateTime?,
          );
        },
      ),

      // Alias for distance-pace-gut-entry (for consistency)
      // REDIRECTED: Now points to NewActivityScreen instead of old DistancePaceGutEntryScreen
      GoRoute(
        path: '/distance-pace-gut-entry',
        name: 'distance-pace-gut-entry',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return NewActivityScreen(
            initialDate: extra?['initialDate'] as DateTime?,
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
            case 'survey':
              initialTab = 2;
              break;
            case 'settings':
              initialTab = 3;
              break;
            default:
              initialTab = 0;
          }
          
          return TabsScreen(initialTabIndex: initialTab);
        },
      ),

      // Activity Detail Screen - Shows nutrition plan and activity details
      // SIMPLIFIED: Only activityId is required - all data loaded from database
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as int?;
          if (activityId == null) {
            return const Scaffold(
              body: Center(
                child: Text('Missing activity ID'),
              ),
            );
          }
          return ActivityDetailScreen(
            activityId: activityId,
            isNewActivity: extra?['isNewActivity'] as bool? ?? false,
          );
        },
      ),

      // Activity Detail Screen alias - for navigation from adjust macros
      GoRoute(
        path: '/current-plan',
        name: 'current-plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as int?;
          if (activityId == null) {
            return const Scaffold(
              body: Center(
                child: Text('Missing activity ID'),
              ),
            );
          }
          return ActivityDetailScreen(
            activityId: activityId,
            isNewActivity: extra?['isNewActivity'] as bool? ?? false,
          );
        },
      ),
      
      // Adjust Macros Screen - Fine-tune macro targets before generating plan
      GoRoute(
        path: '/adjust-macros',
        name: 'adjust-macros',
        builder: (context, state) => const AdjustMacrosScreen(),
      ),

      // Events list
      GoRoute(
        path: '/events',
        name: 'events-list',
        builder: (context, state) => const EventsListScreen(),
      ),

      // Pro Version Screen - Premium features showcase
      GoRoute(
        path: '/pro',
        name: 'pro-version',
        builder: (context, state) => const ProVersionScreen(),
      ),

      // Settings Screen - User profile and preferences
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Preferences Screen - Edit profile and preferences with save button
      GoRoute(
        path: '/settings/preferences',
        name: 'settings-preferences',
        builder: (context, state) => const PreferencesScreen(),
      ),

      // Sport Settings Screen - Cycling, swimming, and sport-specific preferences
      GoRoute(
        path: '/settings/sport-settings',
        name: 'settings-sport-settings',
        builder: (context, state) => const SportSettingsScreen(),
      ),

      // Food Preferences Screen - Edit food preferences from settings
      GoRoute(
        path: '/settings/food-preferences',
        name: 'settings-food-preferences',
        builder: (context, state) => const settings.FoodPreferencesScreen(),
      ),

      // Add Food Screen - Add foods from settings food preferences
      GoRoute(
        path: '/settings/food-preferences/add-food',
        name: 'settings-add-food',
        builder: (context, state) => const AddFoodScreen(),
      ),

      // Help & Feedback Screen - Support and feedback collection
      GoRoute(
        path: '/help',
        name: 'help-feedback',
        builder: (context, state) => const HelpFeedbackScreen(),
      ),
      
      // Swap/Add Food Screen - Add or swap foods in nutrition plan
      // SIMPLIFIED: Only activityId is needed - eliminates provider instance mismatches
      GoRoute(
        path: '/swap-food',
        name: 'swap-food',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as int?;
          final isNewActivity = extra?['isNewActivity'] as bool? ?? false;
          if (activityId == null) {
            return const Scaffold(
              body: Center(
                child: Text('Missing activity'),
              ),
            );
          }
          return SwapFoodScreen(
            foodToSwapId: extra?['foodToSwapId'] as String?,
            foodToSwapName: extra?['foodToSwapName'] as String?,
            category: extra?['category'] as String? ?? 'before_run',
            activityId: activityId,
            isNewActivity: isNewActivity,
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
            dayId: extra?['dayId'] as int,
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
            dayId: extra?['dayId'] as int,
            mealType: extra?['mealType'] as MealType,
          );
        },
      ),

      // User Journal Routes
      
      // Plan Rating Screen - Rate how well a nutrition plan worked
      GoRoute(
        path: '/plan-how-well/:activityId',
        name: 'plan-how-well',
        builder: (context, state) {
          final activityIdParam = state.pathParameters['activityId']!;
          final activityId = int.tryParse(activityIdParam);
          if (activityId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid activity ID')),
            );
          }
          return PlanHowWellScreen(activityId: activityId);
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
        path: '/voice-memo/:activityId',
        name: 'voice-memo',
        builder: (context, state) {
          final activityIdParam = state.pathParameters['activityId']!;
          final activityId = int.tryParse(activityIdParam);
          if (activityId == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid activity ID')),
            );
          }
          int? rating;
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            rating = extra['rating'] as int?;
          } else {
            final ratingParam = state.uri.queryParameters['rating'];
            rating = ratingParam != null ? int.tryParse(ratingParam) : null;
          }
          return VoiceMemoScreen(
            activityId: activityId,
            rating: rating,
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
  });

  // Convenience getter for accessing the router
  static GoRouter router(WidgetRef ref) => ref.watch(routerProvider);
}
