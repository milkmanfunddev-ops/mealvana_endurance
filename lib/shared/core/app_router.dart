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
// New onboarding PageView (December 2025 redesign)
// Note: Old food_preferences_screen.dart moved to /archived folder (replaced by food_preferences_v2_screen.dart)
import '../../features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import '../../features/onboarding/domain/dietary_preference.dart';
import '../../features/onboarding/domain/allergy.dart';
// Onboarding screens that support both onboarding and settings modes
import '../../features/onboarding/presentation/screens/dietary_preference_screen.dart';
import '../../features/onboarding/presentation/screens/allergies_screen.dart';
import '../../features/onboarding/presentation/screens/running_details_screen.dart';
import '../../features/onboarding/presentation/screens/cycling_details_screen.dart';
import '../../features/onboarding/presentation/screens/swimming_details_screen.dart';
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
import '../../features/settings/presentation/screens/food_settings_consolidated_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_hub_screen.dart';
import '../../features/settings/presentation/screens/sport_preferences_hub_screen.dart';
import '../../features/settings/presentation/screens/help_feedback_screen.dart';
import '../core/screen_mode.dart';
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
import '../screens/food_detail_screen.dart';
// Coach mode screens
import '../../features/coach_mode/presentation/screens/coach_dashboard_screen.dart';
import '../../features/coach_mode/presentation/screens/athlete_detail_screen.dart';
import '../../features/coach_mode/presentation/screens/my_coaches_screen.dart';
import '../../features/coach_mode/presentation/screens/athlete_feedback_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_registration_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_directory_screen.dart';

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
            // User exists but hasn't completed onboarding - start over from welcome
            if (!appStartupData.hasCompletedOnboarding) {
              return '/welcome';
            }
            // User has logged out but still has local data - go to welcome to sign back in
            // This allows them to sign in and access their existing data
            if (appStartupData.isLoggedOut) {
              return '/welcome';
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
      
      // Onboarding Flow (PageView-based with swipe navigation)
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPageViewScreen(),
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
            initialDistance: extra?['distance'] as double?,
            initialPace: extra?['goalPace'] as double?,
            activityId: extra?['activityId'] as String?,
            eventId: extra?['eventId'] as String?,
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
            initialDistance: extra?['distance'] as double?,
            initialPace: extra?['goalPace'] as double?,
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
          final activityId = extra?['activityId'] as String?;
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
            isCoachView: extra?['isCoachView'] as bool? ?? false,
          );
        },
      ),

      // Activity Detail Screen alias - for navigation from adjust macros
      GoRoute(
        path: '/current-plan',
        name: 'current-plan',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final activityId = extra?['activityId'] as String?;
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
            isCoachView: extra?['isCoachView'] as bool? ?? false,
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

      // Food Preferences Hub - 2-tier navigation hub for all food settings
      GoRoute(
        path: '/settings/food-preferences-hub',
        name: 'settings-food-preferences-hub',
        builder: (context, state) => const FoodPreferencesHubScreen(),
      ),

      // Sport Preferences Hub - 2-tier navigation hub for all sport settings
      GoRoute(
        path: '/settings/sport-preferences-hub',
        name: 'settings-sport-preferences-hub',
        builder: (context, state) => const SportPreferencesHubScreen(),
      ),

      // Food Preferences Consolidated Screen - All food-related settings in one place (DEPRECATED - kept for backward compatibility)
      GoRoute(
        path: '/settings/food-preferences-consolidated',
        name: 'settings-food-preferences-consolidated',
        builder: (context, state) => const FoodSettingsConsolidatedScreen(),
      ),

      // Food Preferences Screen - Edit food preferences from settings
      GoRoute(
        path: '/settings/food-preferences',
        name: 'settings-food-preferences',
        builder: (context, state) => const settings.FoodPreferencesScreen(),
      ),

      // Dietary Preference Settings Screen - Reuses onboarding screen with settings mode
      GoRoute(
        path: '/settings/dietary-preference',
        name: 'settings-dietary-preference',
        builder: (context, state) => const DietaryPreferenceScreen(mode: ScreenMode.settings),
      ),

      // Allergies Settings Screen - Reuses onboarding screen with settings mode
      GoRoute(
        path: '/settings/allergies',
        name: 'settings-allergies',
        builder: (context, state) => const AllergiesScreen(mode: ScreenMode.settings),
      ),

      // Running Details Settings Screen - Reuses onboarding screen with settings mode
      GoRoute(
        path: '/settings/running-details',
        name: 'settings-running-details',
        builder: (context, state) => const RunningDetailsScreen(mode: ScreenMode.settings),
      ),

      // Cycling Details Settings Screen - Reuses onboarding screen with settings mode
      GoRoute(
        path: '/settings/cycling-details',
        name: 'settings-cycling-details',
        builder: (context, state) => const CyclingDetailsScreen(mode: ScreenMode.settings),
      ),

      // Swimming Details Settings Screen - Reuses onboarding screen with settings mode
      GoRoute(
        path: '/settings/swimming-details',
        name: 'settings-swimming-details',
        builder: (context, state) => const SwimmingDetailsScreen(mode: ScreenMode.settings),
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
          final activityId = extra?['activityId'] as String?;
          final isNewActivity = extra?['isNewActivity'] as bool? ?? false;
          final isCoachView = extra?['isCoachView'] as bool? ?? false;
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
            isCoachView: isCoachView,
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

      // Food Detail Screen - Unified screen for adding/editing foods
      // Returns FoodDetailResult when saved, 'DELETE:foodId' when deleted, or null when cancelled
      GoRoute(
        path: '/food-detail',
        name: 'food-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('Missing food data')),
            );
          }
          return FoodDetailScreen(
            foodData: extra['foodData'] as FoodDetailData,
            mode: extra['mode'] as FoodDetailMode,
            screenContext: extra['screenContext'] as FoodDetailContext? ?? FoodDetailContext.addFood,
            preSelectedCategories: extra['preSelectedCategories'] as List<int>?,
            showCategories: extra['showCategories'] as bool? ?? true,
            showProductType: extra['showProductType'] as bool? ?? true,
            allowDelete: extra['allowDelete'] as bool? ?? false,
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
          final activityId = state.pathParameters['activityId']!;
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
          final activityId = state.pathParameters['activityId']!;
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

      // ============================================================================
      // COACH MODE ROUTES
      // ============================================================================

      // Coach Dashboard - Main hub for coaches to manage athletes
      GoRoute(
        path: '/coach',
        name: 'coach-dashboard',
        builder: (context, state) => const CoachDashboardScreen(),
      ),

      // Athlete Detail - View athlete's activities and add feedback
      GoRoute(
        path: '/coach/athlete/:relationshipId',
        name: 'coach-athlete-detail',
        builder: (context, state) {
          final relationshipId = state.pathParameters['relationshipId']!;
          return AthleteDetailScreen(relationshipId: relationshipId);
        },
      ),

      // My Coaches - Athlete's view of connected coaches
      GoRoute(
        path: '/my-coaches',
        name: 'my-coaches',
        builder: (context, state) => const MyCoachesScreen(),
      ),

      // Athlete Feedback - Athletes view messages from coaches
      GoRoute(
        path: '/athlete/feedback',
        name: 'athlete-feedback',
        builder: (context, state) => const AthleteFeedbackScreen(),
      ),

      // Coach Registration - Apply to become a coach
      GoRoute(
        path: '/coach/apply',
        name: 'coach-apply',
        builder: (context, state) => const CoachRegistrationScreen(),
      ),

      // Coach Directory - Athletes browse and request coaches
      GoRoute(
        path: '/coach-directory',
        name: 'coach-directory',
        builder: (context, state) => const CoachDirectoryScreen(),
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
