// Screen smoke suite — auth screens + miscellaneous feature screens.
//
// Coverage: 10 screens (EmailLoginScreen, EmailSignupScreen,
// ForgotPasswordScreen, VerifyResetCodeScreen, SetNewPasswordScreen,
// ActivitiesListScreen,
// SurveyScreen, VideoPlayerScreen, FoodDetailScreen, BarcodeScannerScreen).
//
// NOTE: CalendarMonthScreen was a dead mock-data screen (0 nav references).
// Deleted 2026-07-01; its smoke test group removed from this file.
// RecipesScreen and ShareNutritionPlanScreen were archived 2026-10-07 (round
// develop-2026-10, ticket 26); their smoke groups were removed, as was
// AiCoachChatScreen's when Jade was archived (ticket 27).
//
// Auth screens read contentServiceProvider (synchronous Provider) and the
// auth controllers (AsyncNotifier<void> that returns synchronously), so
// pumpAndSettle is safe for them.
//
// Screens that kick off async work in initState / build (ActivitiesListScreen)
// use settle:false so the test doesn't time out on a never-resolving Future.
//
// FINDING: SurveyScreen has a broken relative import
// (`../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart` —
// 9 levels above the package root). The test is therefore skipped; see BUG #1.
//
// BarcodeScannerScreen uses MobileScanner which requires a native camera
// channel. settle:false is used, but the test may crash on a native-channel
// call in CI; see PATROL NOTE below.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Auth screens
import 'package:mealvana_endurance/features/auth/presentation/screens/email_login_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_reset_code_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/set_new_password_screen.dart';

// Auth providers needed for overrides
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';

// Activities list screen

// Survey screen

// Video player screen
import 'package:mealvana_endurance/features/education/presentation/screens/video_player_screen.dart';

// Food detail screen
import 'package:mealvana_endurance/shared/screens/food_detail_screen.dart';

// Barcode scanner screen
import 'package:mealvana_endurance/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart';

import '../helpers/widget_test_harness.dart';

// ---------------------------------------------------------------------------
// Fake controllers
// ---------------------------------------------------------------------------

/// Fake PostOnboardingAuthController that resolves immediately so auth screens
/// can settle without hitting Supabase.
class _FakePostOnboardingAuthController extends PostOnboardingAuthController {
  @override
  FutureOr<void> build() {
    // Synchronous return — no Supabase call.
  }
}

/// Fake PasswordRecoveryController that resolves immediately.
class _FakePasswordRecoveryController extends PasswordRecoveryController {
  @override
  FutureOr<void> build() {
    // Synchronous return — no Supabase call.
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Auth screen smoke tests', () {
    testWidgets('EmailLoginScreen renders without overflow', (tester) async {
      await smokeScreen(
        tester,
        const EmailLoginScreen(),
        overrides: [
          postOnboardingAuthControllerProvider.overrideWith(
            _FakePostOnboardingAuthController.new,
          ),
        ],
      );
    });

    testWidgets('EmailSignupScreen renders without overflow', (tester) async {
      await smokeScreen(
        tester,
        const EmailSignupScreen(),
        overrides: [
          postOnboardingAuthControllerProvider.overrideWith(
            _FakePostOnboardingAuthController.new,
          ),
        ],
      );
    });

    testWidgets('ForgotPasswordScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const ForgotPasswordScreen(),
        overrides: [
          passwordRecoveryControllerProvider.overrideWith(
            _FakePasswordRecoveryController.new,
          ),
        ],
      );
    });

    testWidgets('VerifyResetCodeScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const VerifyResetCodeScreen(email: 'test@example.com'),
        overrides: [
          passwordRecoveryControllerProvider.overrideWith(
            _FakePasswordRecoveryController.new,
          ),
        ],
      );
    });

    testWidgets('SetNewPasswordScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const SetNewPasswordScreen(),
        overrides: [
          passwordRecoveryControllerProvider.overrideWith(
            _FakePasswordRecoveryController.new,
          ),
        ],
      );
    });
  });

  // ActivitiesListScreen smoke removed with the screen itself — orphaned
  // since the home-shell switchover, deleted by carb-loading@v1's dead-code
  // retirement (commit 09f8cce7).

  group('Video player screen smoke test', () {
    // VideoPlayerScreen calls VideoPlayerController.networkUrl().initialize()
    // in initState. In the test environment the network is unavailable so the
    // controller will set _hasError=true and render the error state. settle:false
    // avoids a timeout waiting for the Future; we assert no *crash* occurs.
    testWidgets('VideoPlayerScreen builds (error state, no crash)', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const VideoPlayerScreen(
          title: 'Test Video',
          videoUrl: 'https://example.com/video.mp4',
        ),
        settle: false,
        // Overflow enforcement skipped: the video error card may overflow on
        // some sizes before the layout fully settles in settle:false mode.
        overflowSizes: const [],
      );
    });
  });

  group('Food detail screen smoke test', () {
    // FoodDetailScreen is a pure form widget — no provider reads in build.
    testWidgets('FoodDetailScreen renders without overflow', (tester) async {
      await smokeScreen(
        tester,
        FoodDetailScreen(
          foodData: FoodDetailData(
            id: 'smoke-food-id',
            name: 'Test Gel',
            carbsPerServing: 22,
            caloriesPerServing: 100,
            categoryIds: const [1, 2, 3],
          ),
          mode: FoodDetailMode.createNew,
          screenContext: FoodDetailContext.addFood,
        ),
      );
    });
  });

  group('Barcode scanner screen smoke test', () {
    // PATROL NOTE: BarcodeScannerScreen instantiates MobileScannerController
    // in initState, which opens the native camera channel. In a pure widget-
    // test environment (no native runner) this will throw a MissingPluginException
    // on the method channel. settle:false + overflowSizes:[] lets us at least
    // assert the widget tree constructs before the channel call fires, but the
    // test may still fail in CI if the exception propagates before the first
    // pump. Marked Patrol-only; the true camera flow is covered by Patrol.
    testWidgets(
      'BarcodeScannerScreen builds before native channel fires (Patrol-only)',
      (tester) async {
        await smokeScreen(
          tester,
          const BarcodeScannerScreen(category: 'add_food'),
          settle: false,
          overflowSizes: const [],
        );
      },
      // Remove this skip to observe the native-channel crash in CI logs.
      // The underlying code is correct; the test environment is the limitation.
      skip: true, // PATROL-ONLY: MobileScanner requires a native camera channel
      // unavailable in flutter-test; run in Patrol on device/emulator.
    );
  });
}
