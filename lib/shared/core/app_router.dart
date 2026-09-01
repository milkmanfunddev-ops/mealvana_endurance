import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../features/app_startup/application/app_startup_provider.dart';
import '../services/app_external_deps.dart';
import '../services/app_config.dart';
import '../../main.dart' show sentryNavigatorKey;

// Import all screens
import '../../features/app_startup/presentation/screens/force_upgrade_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/nutrition_plan/presentation/screens/new_activity_screen.dart';
// Onboarding PageView (2026-08 redesign). Food preferences left the
// onboarding flow entirely — food is managed via the Settings screens.
import '../../features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
// Screens that survived the onboarding redesign for their /settings/* routes
import '../../features/onboarding/presentation/screens/dietary_preference_screen.dart';
import '../../features/onboarding/presentation/screens/allergies_screen.dart';
import '../../features/onboarding/presentation/screens/running_details_screen.dart';
import '../../features/onboarding/presentation/screens/cycling_details_screen.dart';
import '../../features/onboarding/presentation/screens/swimming_details_screen.dart';
import '../../features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import '../../features/auth/presentation/screens/email_signup_screen.dart';
import '../../features/auth/presentation/screens/email_login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_reset_code_screen.dart';
import '../../features/auth/presentation/screens/set_new_password_screen.dart';
import '../../features/nutrition_plan/presentation/screens/activity_detail_screen.dart';
import '../../features/nutrition_plan/presentation/screens/fuel_log_screen.dart';
import '../../features/nutrition_plan/presentation/screens/adjust_macros_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/nutrition_plan/presentation/screens/swap_food_screen.dart';
import '../../features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart';
import '../../features/settings/presentation/screens/sport_settings_screen.dart';
import '../../features/settings/presentation/screens/preferences_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_screen.dart'
    as settings;
import '../../features/settings/presentation/screens/food_settings_consolidated_screen.dart';
import '../../features/settings/presentation/screens/food_preferences_hub_screen.dart';
import '../../features/formula_kit/domain/formula_phase.dart';
import '../../features/formula_kit/presentation/screens/formula_detail_screen.dart';
import '../../features/formula_kit/presentation/screens/formula_editor_screen.dart';
import '../../features/formula_kit/presentation/screens/formula_library_screen.dart';
import '../../features/settings/presentation/screens/sport_preferences_hub_screen.dart';
import '../../features/settings/presentation/screens/help_feedback_screen.dart';
import '../../features/personal_templates/presentation/screens/personal_templates_screen.dart';
import '../../features/settings/presentation/screens/connected_apps_screen.dart';
import '../../features/settings/presentation/screens/privacy_settings_screen.dart';
import '../../features/privacy/presentation/screens/privacy_consent_screen.dart';
import '../services/privacy/analytics_consent.dart';
import '../../features/settings/presentation/screens/sweat_profile_screen.dart';
import '../../features/settings/presentation/screens/nutrition_targets_screen.dart';
import '../../features/settings/presentation/screens/nutrition_profile_screen.dart';
import '../../features/settings/presentation/screens/coach_connection_screen.dart';
import '../core/screen_mode.dart';
import '../../features/barcode_scanning/presentation/screens/add_food_screen.dart';
import '../../features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart';
import '../../features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart';
import '../../features/carb_loading/domain/meal_type.dart';
import '../widgets/tabs_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/events/presentation/screens/event_form_screen.dart';
import '../../features/race_checklist/presentation/screens/race_checklist_screen.dart';
import '../../features/education/presentation/screens/education_screen.dart';
import '../../features/education/presentation/screens/video_player_screen.dart';
import '../../features/subscription/application/pro_gate.dart';
import '../../features/subscription/presentation/pro_gate_redirect.dart';
import '../../features/subscription/presentation/screens/pro_version_screen.dart';
import '../../features/ai_credits/presentation/screens/buy_credits_screen.dart';
import '../screens/food_detail_screen.dart';
// Coach mode screens
import '../../features/coach_mode/presentation/screens/my_coaches_screen.dart';
import '../../features/coach_mode/presentation/screens/athlete_feedback_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_registration_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_directory_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_chat_screen.dart';
import '../../features/coach_mode/presentation/screens/coach_portal_screen.dart';
import '../../features/coach_mode/application/coach_service.dart';
// Mealvana AI AI coach
import '../../features/ai_coach/presentation/screens/ai_coach_chat_screen.dart';
// Meal logging screens
import '../../features/meal_logging/presentation/screens/edit_meal_log_screen.dart';
import '../../features/meal_logging/presentation/screens/manual_log_screen.dart';
import '../../features/meal_logging/presentation/screens/photo_capture_screen.dart';
import '../../features/meal_logging/presentation/screens/describe_meal_screen.dart';
import '../../features/meal_logging/presentation/screens/meal_review_screen.dart';
import '../../features/meal_logging/presentation/screens/recent_saved_picker_screen.dart';
import '../../features/meal_logging/presentation/screens/recipe_picker_screen.dart';

/// Notifier that triggers GoRouter redirect re-evaluation on auth state changes.
/// Used by AuthListenerService to signal sign-out/sign-in events.
class AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Singleton provider for the auth change notifier
final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier();
});

/// Central router configuration for the Mealvana Endurance app
/// Following Andrea Bizzotto's deep link pattern
class AppRouter {
  // Router provider with ref access for redirect logic
  static final routerProvider = Provider<GoRouter>((ref) {
    final authChangeNotifier = ref.read(authChangeNotifierProvider);
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authChangeNotifier,
      // Use Sentry navigator key for screenshot capture in feedback widget
      navigatorKey: sentryNavigatorKey,
      // SentryNavigatorObserver records screen transitions as Sentry breadcrumbs
      // and navigation spans for performance monitoring.
      observers: [SentryNavigatorObserver()],
      // Redirect logic based on app startup state
      redirect: (context, state) {
        final currentPath = state.uri.path;

        // Allow navigation to force-upgrade route always
        if (currentPath == '/force-upgrade') {
          return null;
        }

        // Metered meal-AI routes fail closed. Hiding the entry points is the
        // primary UX, while this guard also blocks stale deep links from an
        // older build when the release flag is off. `/jade` rides the same
        // flag: its banner entry point is intentionally unrendered, and the
        // chat screen calls the jade-chat edge function on every send.
        // `/buy-credits` rides it too — with every AI surface hidden there is
        // nothing to buy credits for, and the 402 paywall flows that push it
        // all originate from the gated AI calls.
        if ((currentPath == '/meal-log/photo' ||
                currentPath == '/meal-log/describe' ||
                currentPath == '/jade' ||
                currentPath == '/buy-credits') &&
            !ref.read(appConfigProvider).describeMealEnabled) {
          return '/';
        }

        // ANALYTICS CONSENT.
        //
        // The screen is no longer a gate that fires ahead of everything. It is
        // reached two ways, both of which route TO it explicitly:
        //   - new users, from Welcome's "Get Started" (see welcome_screen.dart),
        //     so it reads as the first step of onboarding rather than a popup;
        //   - existing users who were onboarded before the prompt existed, from
        //     the startup `data:` branch below.
        //
        // Only strict-regime users (EEA/UK, Washington) are ever sent here —
        // `needsPrompt` encodes that. Everyone else gets disclosure + an
        // always-available Settings → Privacy opt-out instead of a screen.
        //
        // Let it render once we're on it. Without this the session check below
        // bounces /privacy-consent to /welcome whenever `signInAnonymously()`
        // failed (welcome_screen swallows that error), producing an infinite
        // redirect loop between the two.
        if (currentPath == '/privacy-consent') {
          return null;
        }

        // Public routes that don't require auth (welcome, onboarding, auth screens)
        final isPublicRoute =
            currentPath == '/welcome' ||
            currentPath.startsWith('/onboarding') ||
            currentPath.startsWith('/auth');

        // For non-root, non-public routes: check Supabase auth directly
        // This ensures sign-out navigates back to welcome from ANY screen
        // We check Supabase session directly (not appStartupProvider) because
        // appStartupProvider may be in loading state during the redirect
        if (currentPath != '/' && !isPublicRoute) {
          final supabase = ref.read(appExternalDepsProvider).supabaseClient;
          if (supabase.auth.currentSession == null) {
            return '/welcome';
          }
          // Pro gate: meal planning (/food/*, /vana/*) is a Pro-only surface.
          // The routes land in Phase 4; the guard is here so a deep link from
          // a newer build, or a tab tap once the Food tab exists, resolves to
          // the paywall instead of a locked screen. `isProGatedPath` is
          // checked first so ordinary navigation never builds the
          // subscription provider. The server row is the real paywall
          // (edge functions call has_entitlement); this is UX.
          if (isProGatedPath(currentPath) && !isProUnlocked(ref)) {
            return '/pro';
          }
          return null; // Allow navigation to protected routes when authenticated
        }

        // For public routes, don't redirect (user is already where they should be)
        if (isPublicRoute) {
          return null;
        }

        // For root path, check app startup state and redirect appropriately
        final appStartupState = ref.read(appStartupProvider);

        return appStartupState.maybeWhen(
          data: (appStartupData) {
            // CRITICAL: Force upgrade required - block all other navigation
            if (appStartupData.forceUpgradeRequired) {
              return '/force-upgrade';
            }
            // Schema resync failed - send to welcome to re-authenticate
            // (Successful resync continues with normal startup in app_startup_provider)
            if (appStartupData.resyncRequired) {
              return '/welcome';
            }
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

            // Existing user, onboarded before the consent prompt existed, in a
            // strict region. New users can't reach this — !hasCompletedOnboarding
            // short-circuits to /welcome above — so this is only the backfill.
            //
            // Placed HERE, not at the top of the redirect, on purpose: reaching
            // this branch means appStartupProvider has returned data, which
            // means the region lookup has completed (it is awaited in that
            // provider's Future.wait). A top-of-redirect check would run on the
            // very first parse of '/', while startup is still loading and the
            // region is still an unresolved device-signal guess — and would
            // prompt Californians.
            if (ref.read(analyticsConsentProvider).needsPrompt) {
              return '/privacy-consent';
            }

            // User is fully onboarded - go to main app
            return '/main';
          },
          // While loading or on error, stay on root (AppStartupWidget handles UI)
          orElse: () => null,
        );
      },
      routes: [
        // Analytics consent - strict regions only (EEA/UK, Washington).
        // `next` is where to go once a decision is recorded: '/onboarding' when
        // entered from Get Started, '/' for the existing-user backfill (which
        // then resolves through the startup redirect to /main).
        GoRoute(
          path: '/privacy-consent',
          name: 'privacy-consent',
          builder: (context, state) => PrivacyConsentScreen(
            next: state.uri.queryParameters['next'] ?? '/',
          ),
        ),
        // Force Upgrade Screen - Mandatory update required
        GoRoute(
          path: '/force-upgrade',
          name: 'force-upgrade',
          builder: (context, state) {
            // Try to get version info from appStartupProvider
            final appStartupState = ref.read(appStartupProvider);
            String currentVersion = '0.0.0';
            String requiredVersion = '0.0.0';

            appStartupState.whenData((data) {
              if (data.forceUpgradeRequired) {
                currentVersion = data.currentVersion ?? '0.0.0';
                requiredVersion = data.requiredVersion ?? '0.0.0';
              }
            });

            // Also check for explicit extra data (for testing or direct navigation)
            final extra = state.extra as Map<String, dynamic>?;
            if (extra != null) {
              currentVersion =
                  extra['currentVersion'] as String? ?? currentVersion;
              requiredVersion =
                  extra['requiredVersion'] as String? ?? requiredVersion;
            }

            return ForceUpgradeScreen(
              currentVersion: currentVersion,
              requiredVersion: requiredVersion,
            );
          },
        ),

        // Welcome Screen
        GoRoute(
          path: '/welcome',
          name: 'welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),

        // Onboarding Flow (PageView-based with swipe navigation).
        // `?page=last` opens on the final page — used by the post-onboarding
        // auth screen's back fallback so a stack-replaced arrival doesn't
        // rewind the athlete to the first question.
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => OnboardingPageViewScreen(
            startAtLastPage: state.uri.queryParameters['page'] == 'last',
          ),
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

        // Password Recovery Flow
        GoRoute(
          path: '/auth/forgot-password',
          name: 'auth-forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),

        GoRoute(
          path: '/auth/verify-reset-code',
          name: 'auth-verify-reset-code',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final email = extra?['email'] as String? ?? '';
            return VerifyResetCodeScreen(email: email);
          },
        ),

        GoRoute(
          path: '/auth/set-new-password',
          name: 'auth-set-new-password',
          builder: (context, state) => const SetNewPasswordScreen(),
        ),

        // REDIRECTED: Old routes now point to NewActivityScreen (multi-sport Kyle design)
        // Supports pre-population from synced activities and events
        GoRoute(
          path: '/distancepacegut',
          name: 'distancepacegut',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return NewActivityScreen(
              initialDate: extra?['initialDate'] as DateTime?,
              initialDistance: extra?['distance'] as double?,
              initialDurationMinutes: extra?['initialDurationMinutes'] as int?,
              initialPace: extra?['goalPace'] as double?,
              initialTitle:
                  extra?['initialTitle'] as String? ??
                  extra?['eventName'] as String?,
              activityId: extra?['activityId'] as String?,
              eventId: extra?['eventId'] as String?,
              forUserId:
                  extra?['forUserId']
                      as String?, // NEW: For coach creating for athlete
              // Activity type for tab selection
              activityType: extra?['activityType'] as String?,
              // Cycling-specific parameters
              cyclingSpeedMph: extra?['cyclingSpeedMph'] as double?,
              cyclingTerrain: extra?['cyclingTerrain'] as String?,
              cyclingIndoorOutdoor: extra?['cyclingIndoorOutdoor'] as String?,
              cyclingElevationGainFt: extra?['cyclingElevationGainFt'] as int?,
              cyclingSessionGoal: extra?['cyclingSessionGoal'] as String?,
              // Swimming-specific parameters
              swimmingPacePer100mSeconds:
                  extra?['swimmingPacePer100mSeconds'] as int?,
              swimmingPoolOrOpenWater:
                  extra?['swimmingPoolOrOpenWater'] as String?,
              swimmingWaterTempC: extra?['swimmingWaterTempC'] as double?,
              // Shared parameters
              intensityTarget: extra?['intensityTarget'] as String?,
              timeBeforeMinutes: extra?['timeBeforeMinutes'] as int?,
              // Brick event subtype distances
              brickSwimDistanceMeters:
                  extra?['brickSwimDistanceMeters'] as double?,
              brickBikeDistanceMiles:
                  extra?['brickBikeDistanceMiles'] as double?,
              brickRunDistanceMiles: extra?['brickRunDistanceMiles'] as double?,
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
              initialDurationMinutes: extra?['initialDurationMinutes'] as int?,
              initialPace: extra?['goalPace'] as double?,
              initialTitle:
                  extra?['initialTitle'] as String? ??
                  extra?['eventName'] as String?,
              activityId: extra?['activityId'] as String?,
              eventId: extra?['eventId'] as String?,
              forUserId:
                  extra?['forUserId']
                      as String?, // NEW: For coach creating for athlete
              // Activity type for tab selection
              activityType: extra?['activityType'] as String?,
              // Cycling-specific parameters
              cyclingSpeedMph: extra?['cyclingSpeedMph'] as double?,
              cyclingTerrain: extra?['cyclingTerrain'] as String?,
              cyclingIndoorOutdoor: extra?['cyclingIndoorOutdoor'] as String?,
              cyclingElevationGainFt: extra?['cyclingElevationGainFt'] as int?,
              cyclingSessionGoal: extra?['cyclingSessionGoal'] as String?,
              // Swimming-specific parameters
              swimmingPacePer100mSeconds:
                  extra?['swimmingPacePer100mSeconds'] as int?,
              swimmingPoolOrOpenWater:
                  extra?['swimmingPoolOrOpenWater'] as String?,
              swimmingWaterTempC: extra?['swimmingWaterTempC'] as double?,
              // Shared parameters
              intensityTarget: extra?['intensityTarget'] as String?,
              timeBeforeMinutes: extra?['timeBeforeMinutes'] as int?,
              // Brick event subtype distances
              brickSwimDistanceMeters:
                  extra?['brickSwimDistanceMeters'] as double?,
              brickBikeDistanceMiles:
                  extra?['brickBikeDistanceMiles'] as double?,
              brickRunDistanceMiles: extra?['brickRunDistanceMiles'] as double?,
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

            // Tab indices:
            // Mobile: 0=activities, 1=nutrition, 2=events, 3=learn
            // Web:    0=activities, 1=nutrition, 2=coach, 3=events, 4=learn
            final hasCoachTab = kIsWeb;

            // Activities + Nutrition merged into the single Fuel Timeline tab (0).
            switch (tabParam) {
              case 'nutrition':
              case 'activities':
              case 'calendar':
                initialTab = 0;
                break;
              case 'notes':
              case 'workout-notes':
              case 'events':
                initialTab = hasCoachTab ? 2 : 1;
                break;
              case 'survey':
              case 'learn':
                initialTab = hasCoachTab ? 3 : 2;
                break;
              default:
                initialTab = 0;
            }

            return TabsScreen(initialTabIndex: initialTab);
          },
        ),

        // Coach Portal — dedicated route for coach users (web only)
        GoRoute(
          path: '/coach-portal',
          name: 'coach-portal',
          builder: (context, state) {
            return CoachPortalScreen(
              onBackToApp: () => GoRouter.of(context).go('/main'),
            );
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
                body: Center(child: Text('Missing activity ID')),
              );
            }
            return ActivityDetailScreen(
              activityId: activityId,
              isNewActivity: extra?['isNewActivity'] as bool? ?? false,
              isCoachView: extra?['isCoachView'] as bool? ?? false,
              fromTemplate: extra?['fromTemplate'] as bool? ?? false,
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
                body: Center(child: Text('Missing activity ID')),
              );
            }
            return ActivityDetailScreen(
              activityId: activityId,
              isNewActivity: extra?['isNewActivity'] as bool? ?? false,
              isCoachView: extra?['isCoachView'] as bool? ?? false,
              fromTemplate: extra?['fromTemplate'] as bool? ?? false,
            );
          },
        ),

        // Fuel Log Screen - dedicated logging flow with hero transition
        GoRoute(
          path: '/fuel-log',
          name: 'fuel-log',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final activityId = extra?['activityId'] as String?;
            if (activityId == null) {
              return const Scaffold(
                body: Center(child: Text('Missing activity ID')),
              );
            }
            return FuelLogScreen(
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

        // Education / Learn
        GoRoute(
          path: '/learn',
          name: 'learn',
          builder: (context, state) => const EducationScreen(),
        ),

        // Video Player
        GoRoute(
          path: '/learn/video',
          name: 'learn-video',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return VideoPlayerScreen(
              title: extra?['title'] as String? ?? '',
              videoUrl: extra?['videoUrl'] as String? ?? '',
            );
          },
        ),

        // Events list
        GoRoute(
          path: '/events',
          name: 'events-list',
          builder: (context, state) => const EventsListScreen(),
        ),

        // Event creation - supports coach creating for athlete
        GoRoute(
          path: '/events/create',
          name: 'events-create',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return EventFormScreen(forUserId: extra?['forUserId'] as String?);
          },
        ),

        // Race Day Checklist - Gear checklist for an event
        GoRoute(
          path: '/events/:eventId/checklist',
          name: 'race-checklist',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return RaceChecklistScreen(eventId: eventId);
          },
        ),

        // Pro Version Screen - Premium features showcase
        GoRoute(
          path: '/pro',
          name: 'pro-version',
          builder: (context, state) => const ProVersionScreen(),
        ),

        // AI Credits Paywall - purchase credit packs for AI features
        GoRoute(
          path: '/buy-credits',
          name: 'buy-credits',
          builder: (context, state) => const BuyCreditsScreen(),
        ),

        // Settings Screen - User profile and preferences
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),

        // Connected Apps Screen - Training platform integrations (Final Surge, etc.)
        GoRoute(
          path: '/settings/connected-apps',
          name: 'settings-connected-apps',
          builder: (context, state) => const ConnectedAppsScreen(),
        ),

        // Privacy Screen - analytics consent withdrawal + policy/terms links
        GoRoute(
          path: '/settings/privacy',
          name: 'settings-privacy',
          builder: (context, state) => const PrivacySettingsScreen(),
        ),

        // Preferences Screen - Edit profile and preferences with save button
        GoRoute(
          path: '/settings/preferences',
          name: 'settings-preferences',
          builder: (context, state) => const PreferencesScreen(),
        ),

        // Sweat Profile Screen - Detailed sweat rate, sodium, and sweat-test data
        GoRoute(
          path: '/settings/sweat-profile',
          name: 'settings-sweat-profile',
          builder: (context, state) => const SweatProfileScreen(),
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

        // Nutrition Targets - User-configured default macro target overrides
        GoRoute(
          path: '/settings/nutrition-targets',
          name: 'settings-nutrition-targets',
          builder: (context, state) => const NutritionTargetsScreen(),
        ),

        // Nutrition Profile Screen - Body composition, training phase, lifestyle
        GoRoute(
          path: '/settings/nutrition-profile',
          name: 'settings-nutrition-profile',
          builder: (context, state) => const NutritionProfileScreen(),
        ),

        // Personal Templates Screen - Manage saved nutrition plan templates
        GoRoute(
          path: '/settings/templates',
          name: 'settings-templates',
          builder: (context, state) => const PersonalTemplatesScreen(),
        ),

        // Coach Connection Screen - Athlete generates pairing codes & manages coach
        GoRoute(
          path: '/settings/coach-connection',
          name: 'settings-coach-connection',
          builder: (context, state) => const CoachConnectionScreen(),
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
          builder: (context, state) =>
              const DietaryPreferenceScreen(mode: ScreenMode.settings),
        ),

        // Allergies Settings Screen - Reuses onboarding screen with settings mode
        GoRoute(
          path: '/settings/allergies',
          name: 'settings-allergies',
          builder: (context, state) =>
              const AllergiesScreen(mode: ScreenMode.settings),
        ),

        // Running Details Settings Screen - Reuses onboarding screen with settings mode
        GoRoute(
          path: '/settings/running-details',
          name: 'settings-running-details',
          builder: (context, state) =>
              const RunningDetailsScreen(mode: ScreenMode.settings),
        ),

        // Cycling Details Settings Screen - Reuses onboarding screen with settings mode
        GoRoute(
          path: '/settings/cycling-details',
          name: 'settings-cycling-details',
          builder: (context, state) =>
              const CyclingDetailsScreen(mode: ScreenMode.settings),
        ),

        // Swimming Details Settings Screen - Reuses onboarding screen with settings mode
        GoRoute(
          path: '/settings/swimming-details',
          name: 'settings-swimming-details',
          builder: (context, state) =>
              const SwimmingDetailsScreen(mode: ScreenMode.settings),
        ),

        // Add Food Screen - Add foods from settings food preferences
        GoRoute(
          path: '/settings/food-preferences/add-food',
          name: 'settings-add-food',
          builder: (context, state) => const AddFoodScreen(),
        ),

        // Formula Library — browse system Before/During formulas (PR 1).
        GoRoute(
          path: '/settings/food-preferences/formula-library',
          name: 'settings-formula-library',
          builder: (context, state) => const FormulaLibraryScreen(),
          routes: [
            GoRoute(
              path: 'before/:id',
              name: 'settings-formula-detail-before',
              builder: (context, state) => FormulaDetailScreen(
                id: state.pathParameters['id']!,
                phase: FormulaPhase.before,
              ),
            ),
            GoRoute(
              path: 'during/:id',
              name: 'settings-formula-detail-during',
              builder: (context, state) => FormulaDetailScreen(
                id: state.pathParameters['id']!,
                phase: FormulaPhase.during,
              ),
            ),
            GoRoute(
              path: 'after/:id',
              name: 'settings-formula-detail-after',
              builder: (context, state) => FormulaDetailScreen(
                id: state.pathParameters['id']!,
                phase: FormulaPhase.after,
              ),
            ),
            // Personal formulas. `create` is registered before `:id` so the
            // literal segment wins the match. Tapping a personal formula opens
            // the editor directly (no read-only detail screen) — `personal/:id`
            // IS the editor in edit mode.
            GoRoute(
              path: 'personal/create',
              name: 'settings-formula-personal-create',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                final phase =
                    (extra?['phase'] as FormulaPhase?) ?? FormulaPhase.before;
                return FormulaEditorScreen(formulaId: null, phase: phase);
              },
            ),
            GoRoute(
              path: 'personal/:id',
              name: 'settings-formula-personal-edit',
              builder: (context, state) => FormulaEditorScreen(
                formulaId: state.pathParameters['id'],
                // Phase is loaded from the existing formula in the editor
                // controller; this default is unused for edit.
                phase: FormulaPhase.before,
              ),
            ),
          ],
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
            // Return-selection mode (e.g. personal-formula editor) reuses this
            // screen without an activity — it pops a SwapFoodSelection instead.
            final returnSelection = extra?['returnSelection'] as bool? ?? false;
            if (activityId == null && !returnSelection) {
              return const Scaffold(
                body: Center(child: Text('Missing activity')),
              );
            }
            return SwapFoodScreen(
              foodToSwapId: extra?['foodToSwapId'] as String?,
              foodToSwapName: extra?['foodToSwapName'] as String?,
              category: extra?['category'] as String? ?? 'before_run',
              activityId: activityId ?? '',
              isNewActivity: isNewActivity,
              isCoachView: isCoachView,
              returnSelection: returnSelection,
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
              screenContext:
                  extra['screenContext'] as FoodDetailContext? ??
                  FoodDetailContext.addFood,
              preSelectedCategories:
                  extra['preSelectedCategories'] as List<int>?,
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
              dayId: extra?['dayId'] as String,
              mealType: extra?['mealType'] as MealType,
            );
          },
        ),

        // ============================================================================
        // COACH MODE ROUTES
        // Web-only: /coach, /coach/apply, /coach/athlete/:id (coach features)
        // Mobile-only: /my-coaches, /coach-directory, /athlete/feedback (athlete features)
        // ============================================================================

        // Coach Portal - Redirects to /main?tab=coach (coach portal is now a tab)
        GoRoute(
          path: '/coach',
          name: 'coach-dashboard',
          redirect: (context, state) async {
            if (!kIsWeb) return '/settings';

            final coachService = ref.read(coachServiceProvider);
            var isApprovedCoach = await coachService.isCurrentUserCoach();
            if (!isApprovedCoach) {
              isApprovedCoach = await coachService
                  .syncCurrentCoachDataFromSupabase();
            }

            return isApprovedCoach ? '/main?tab=coach' : '/settings';
          },
          builder: (context, state) =>
              const SizedBox(), // Never reached due to redirect
        ),

        // Athlete Detail - Redirect to portal (handled within portal now)
        GoRoute(
          path: '/coach/athlete/:relationshipId',
          name: 'coach-athlete-detail',
          redirect: (context, state) => '/coach',
        ),

        // My Coaches - Athlete's view of connected coaches (MOBILE ONLY)
        GoRoute(
          path: '/my-coaches',
          name: 'my-coaches',
          redirect: (context, state) => kIsWeb ? '/settings' : null,
          builder: (context, state) => const MyCoachesScreen(),
        ),

        // Athlete Feedback - Athletes view messages from coaches (MOBILE ONLY)
        GoRoute(
          path: '/athlete/feedback',
          name: 'athlete-feedback',
          redirect: (context, state) => kIsWeb ? '/settings' : null,
          builder: (context, state) => const AthleteFeedbackScreen(),
        ),

        // Coach Registration - Apply to become a coach (WEB ONLY)
        GoRoute(
          path: '/coach/apply',
          name: 'coach-apply',
          redirect: (context, state) => kIsWeb ? null : '/settings',
          builder: (context, state) => const CoachRegistrationScreen(),
        ),

        // Coach Directory - Athletes browse and request coaches (MOBILE ONLY)
        GoRoute(
          path: '/coach-directory',
          name: 'coach-directory',
          redirect: (context, state) => kIsWeb ? '/settings' : null,
          builder: (context, state) => const CoachDirectoryScreen(),
        ),

        // Coach Chat - Unified chat screen for both coaches and athletes
        // Accessible on both web and mobile platforms
        GoRoute(
          path: '/chat/:relationshipId',
          name: 'coach-chat',
          builder: (context, state) {
            final relationshipId = state.pathParameters['relationshipId']!;
            return CoachChatScreen(relationshipId: relationshipId);
          },
        ),

        // ====================================================================
        // MEAL LOGGING ROUTES
        // ====================================================================
        GoRoute(
          path: '/meal-log/edit',
          name: 'meal-log-edit',
          builder: (context, state) => const EditMealLogScreen(),
        ),

        GoRoute(
          path: '/meal-log/manual',
          name: 'meal-log-manual',
          builder: (context, state) => const ManualLogScreen(),
        ),

        GoRoute(
          path: '/meal-log/photo',
          name: 'meal-log-photo',
          builder: (context, state) => const PhotoCaptureScreen(),
        ),

        GoRoute(
          path: '/meal-log/describe',
          name: 'meal-log-describe',
          builder: (context, state) => const DescribeMealScreen(),
        ),

        GoRoute(
          path: '/meal-log/review',
          name: 'meal-log-review',
          builder: (context, state) => const MealReviewScreen(),
        ),

        GoRoute(
          path: '/meal-log/recent-saved',
          name: 'meal-log-recent-saved',
          builder: (context, state) => const RecentSavedPickerScreen(),
        ),

        GoRoute(
          path: '/meal-log/recipe',
          name: 'meal-log-recipe',
          builder: (context, state) => const RecipePickerScreen(),
        ),

        // ====================================================================
        // MEALVANA AI COACH
        // ====================================================================
        GoRoute(
          path: '/jade',
          name: 'jade-chat',
          builder: (context, state) => const AiCoachChatScreen(),
        ),
      ],

      // Error handling
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
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
