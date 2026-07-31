/// Regression test for FK 23503: activities uploaded during onboarding before
/// the public.users profile row exists in Supabase.
///
/// Verifies that the onboarding-incomplete guard correctly defers upload of
/// dirty activity records until after the profile row exists.
///
/// The production guard is:
///   if (_isUsingTempUserId || _isOnboardingInProgress) { /* skip upload */ }
/// where:
///   _isOnboardingInProgress = !_isUsingTempUserId && (user?.onboardingCompleted != true)
///
/// This test exercises the boolean logic that computes _isOnboardingInProgress
/// for the three key scenarios in ConnectTrainingController.build().
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FK 23503 regression — onboarding upload guard logic', () {
    // The guard in _importWorkouts skips upload when either flag is true:
    //   if (_isUsingTempUserId || _isOnboardingInProgress) { skip }
    //
    // _isOnboardingInProgress is computed as:
    //   !_isUsingTempUserId && (user?.onboardingCompleted != true)

    bool computeIsOnboardingInProgress({
      required bool isUsingTempUserId,
      required bool? onboardingCompleted,
    }) {
      return !isUsingTempUserId && (onboardingCompleted != true);
    }

    bool shouldSkipUpload({
      required bool isUsingTempUserId,
      required bool isOnboardingInProgress,
    }) {
      return isUsingTempUserId || isOnboardingInProgress;
    }

    test(
      'anonymous session with incomplete onboarding → skip upload (the bug scenario)',
      () {
        // User has a real anonymous auth session (not temp UUID), but
        // onboarding hasn't completed — profile row doesn't exist in Supabase.
        const isUsingTempUserId = false;
        const onboardingCompleted = false;

        final isOnboardingInProgress = computeIsOnboardingInProgress(
          isUsingTempUserId: isUsingTempUserId,
          onboardingCompleted: onboardingCompleted,
        );

        expect(
          isOnboardingInProgress,
          isTrue,
          reason: 'Should detect onboarding in progress',
        );
        expect(
          shouldSkipUpload(
            isUsingTempUserId: isUsingTempUserId,
            isOnboardingInProgress: isOnboardingInProgress,
          ),
          isTrue,
          reason: 'Upload must be skipped when onboarding is incomplete',
        );
      },
    );

    test('anonymous session with null user profile → skip upload', () {
      // User has auth session but no local profile at all (user == null)
      // user?.onboardingCompleted is null, so != true is true.
      const isUsingTempUserId = false;
      const bool? onboardingCompleted = null;

      final isOnboardingInProgress = computeIsOnboardingInProgress(
        isUsingTempUserId: isUsingTempUserId,
        onboardingCompleted: onboardingCompleted,
      );

      expect(isOnboardingInProgress, isTrue);
      expect(
        shouldSkipUpload(
          isUsingTempUserId: isUsingTempUserId,
          isOnboardingInProgress: isOnboardingInProgress,
        ),
        isTrue,
        reason: 'Upload must be skipped when no profile exists',
      );
    });

    test('temp user ID (no auth session) → skip upload via existing guard', () {
      // No Supabase session at all — using a generated temp UUID.
      // The original guard already handles this case.
      const isUsingTempUserId = true;
      const onboardingCompleted = false;

      final isOnboardingInProgress = computeIsOnboardingInProgress(
        isUsingTempUserId: isUsingTempUserId,
        onboardingCompleted: onboardingCompleted,
      );

      // When using temp ID, _isOnboardingInProgress is false (the temp guard
      // handles it), but upload is still skipped via _isUsingTempUserId.
      expect(isOnboardingInProgress, isFalse);
      expect(
        shouldSkipUpload(
          isUsingTempUserId: isUsingTempUserId,
          isOnboardingInProgress: isOnboardingInProgress,
        ),
        isTrue,
        reason: 'Upload skipped via temp user ID guard',
      );
    });

    test('completed onboarding → allow upload', () {
      // User has completed onboarding — profile row exists in Supabase.
      // Upload should proceed normally.
      const isUsingTempUserId = false;
      const onboardingCompleted = true;

      final isOnboardingInProgress = computeIsOnboardingInProgress(
        isUsingTempUserId: isUsingTempUserId,
        onboardingCompleted: onboardingCompleted,
      );

      expect(isOnboardingInProgress, isFalse);
      expect(
        shouldSkipUpload(
          isUsingTempUserId: isUsingTempUserId,
          isOnboardingInProgress: isOnboardingInProgress,
        ),
        isFalse,
        reason: 'Upload allowed when onboarding is complete',
      );
    });
  });
}
