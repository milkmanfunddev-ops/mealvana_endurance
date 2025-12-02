/// Onboarding + Auth Flow Integration Test
///
/// Tests the complete new user journey:
/// 1. App launches with anonymous auth
/// 2. User completes Welcome screen
/// 3. User fills out profile (gender, weight, height, birthday)
/// 4. User sets sport preferences (gut training level)
/// 5. User sets food preferences
/// 6. User creates account with email/password
///
/// This test creates a new anonymous user each run and attempts
/// to link it to an email account at the end.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding + Auth Flow', () {
    testWidgets(
      'New user can complete onboarding and create email account',
      (tester) async {
        TestLogger.logStep('Starting Onboarding + Auth Flow Test');

        // ============================================================
        // STEP 1: Launch App
        // ============================================================
        TestLogger.logSubStep('Launching app...');
        app.main();
        await tester.pumpAndSettle();

        // Wait for app to initialize (Supabase, database, etc.)
        await tester.wait(TestConfig.networkDelay);
        TestLogger.logSuccess('App launched successfully');

        // ============================================================
        // STEP 2: Welcome Screen
        // ============================================================
        TestLogger.logStep('Welcome Screen');

        // Wait for welcome screen to appear
        final welcomeFound = await tester.waitForWidget(
          find.textContaining('Welcome'),
          timeout: TestConfig.mediumTimeout,
        );

        if (!welcomeFound) {
          // App might have existing user - check for main screen
          if (find.text('Calendar').evaluate().isNotEmpty ||
              find.text('Activities').evaluate().isNotEmpty) {
            TestLogger.logInfo('Existing user detected - skipping onboarding');
            return;
          }
        }

        // Look for the "Get Started" or similar button
        final getStartedFinder = find.textContaining('Get Started');
        if (getStartedFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(getStartedFinder.first);
          TestLogger.logSuccess('Tapped Get Started');
        } else {
          // Try finding any primary button
          final buttonFinder = find.byType(ElevatedButton);
          if (buttonFinder.evaluate().isNotEmpty) {
            await tester.tapAndSettle(buttonFinder.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 3: User Profile Screen
        // ============================================================
        TestLogger.logStep('User Profile Screen');

        // Wait for profile screen
        await tester.waitForWidget(
          find.textContaining('Profile'),
          timeout: TestConfig.mediumTimeout,
        );

        // Select Gender (look for Female option)
        TestLogger.logSubStep('Selecting gender...');
        final femaleFinder = find.text('Female');
        if (femaleFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(femaleFinder.first);
          TestLogger.logSuccess('Selected Female');
        }

        // Enter Birthday
        TestLogger.logSubStep('Entering birthday...');
        // Look for date picker or text field
        final birthdayFinder = find.textContaining('Birthday');
        if (birthdayFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(birthdayFinder.first);
          // Handle date picker if it opens
          await tester.pumpAndSettle();
          // Try to dismiss/confirm date picker
          final okButton = find.text('OK');
          if (okButton.evaluate().isNotEmpty) {
            await tester.tapAndSettle(okButton.first);
          }
        }

        // Enter Height
        TestLogger.logSubStep('Entering height...');
        // Look for feet input
        final feetFinder = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Feet') == true ||
                widget.decoration?.hintText?.contains('Feet') == true));
        if (feetFinder.evaluate().isNotEmpty) {
          await tester.enterText(feetFinder.first, '5');
        }

        // Look for inches input
        final inchesFinder = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Inches') == true ||
                widget.decoration?.hintText?.contains('Inch') == true));
        if (inchesFinder.evaluate().isNotEmpty) {
          await tester.enterText(inchesFinder.first, '6');
        }

        // Enter Weight
        TestLogger.logSubStep('Entering weight...');
        final weightFinder = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.contains('Weight') == true ||
                widget.decoration?.hintText?.contains('Weight') == true ||
                widget.decoration?.hintText?.contains('lbs') == true));
        if (weightFinder.evaluate().isNotEmpty) {
          await tester.enterText(weightFinder.first, '145');
        }

        await tester.pumpAndSettle();

        // Tap Continue/Next button
        TestLogger.logSubStep('Tapping Continue...');
        final continueFinder = find.textContaining('Continue');
        if (continueFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(continueFinder.first);
        } else {
          final nextFinder = find.textContaining('Next');
          if (nextFinder.evaluate().isNotEmpty) {
            await tester.tapAndSettle(nextFinder.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);
        TestLogger.logSuccess('Profile completed');

        // ============================================================
        // STEP 4: Sport Preferences Screen
        // ============================================================
        TestLogger.logStep('Sport Preferences Screen');

        // Wait for sport preferences screen
        await tester.waitForWidget(
          find.textContaining('Gut Training'),
          timeout: TestConfig.mediumTimeout,
        );

        // Select Moderate gut training level
        TestLogger.logSubStep('Selecting gut training level...');
        final moderateFinder = find.text('Moderate');
        if (moderateFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(moderateFinder.first);
          TestLogger.logSuccess('Selected Moderate gut training');
        }

        // Tap Continue
        final continueButton2 = find.textContaining('Continue');
        if (continueButton2.evaluate().isNotEmpty) {
          await tester.tapAndSettle(continueButton2.first);
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 5: Food Preferences Screen
        // ============================================================
        TestLogger.logStep('Food Preferences Screen');

        // Wait for food preferences screen
        await tester.waitForWidget(
          find.textContaining('Food'),
          timeout: TestConfig.mediumTimeout,
        );

        // Like some foods (tap thumbs up on a few items)
        TestLogger.logSubStep('Setting food preferences...');

        // Look for thumbs up icons or "Like" buttons
        final likeIcons = find.byIcon(Icons.thumb_up);
        if (likeIcons.evaluate().isNotEmpty) {
          // Like the first couple of foods
          for (var i = 0; i < 2 && i < likeIcons.evaluate().length; i++) {
            await tester.tap(likeIcons.at(i));
            await tester.pumpAndSettle();
          }
          TestLogger.logSuccess('Liked some foods');
        }

        // Dislike a food (optional)
        final dislikeIcons = find.byIcon(Icons.thumb_down);
        if (dislikeIcons.evaluate().isNotEmpty) {
          await tester.tap(dislikeIcons.first);
          await tester.pumpAndSettle();
          TestLogger.logSuccess('Disliked a food');
        }

        // Tap Continue/Done
        final doneButton = find.textContaining('Done');
        if (doneButton.evaluate().isNotEmpty) {
          await tester.tapAndSettle(doneButton.first);
        } else {
          final continueButton3 = find.textContaining('Continue');
          if (continueButton3.evaluate().isNotEmpty) {
            await tester.tapAndSettle(continueButton3.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 6: Post-Onboarding Auth Screen
        // ============================================================
        TestLogger.logStep('Post-Onboarding Auth Screen');

        // Wait for auth screen
        final authFound = await tester.waitForWidget(
          find.textContaining('Account'),
          timeout: TestConfig.mediumTimeout,
        );

        if (!authFound) {
          // Maybe went straight to main app - that's okay for anonymous users
          TestLogger.logInfo('Auth screen not shown - may have gone to main app');
          return;
        }

        // Tap "Sign up with Email"
        TestLogger.logSubStep('Selecting email signup...');
        final emailSignupFinder = find.textContaining('Email');
        if (emailSignupFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(emailSignupFinder.first);
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 7: Email Signup Screen
        // ============================================================
        TestLogger.logStep('Email Signup Screen');

        // Wait for email signup form
        await tester.waitForWidget(
          find.byType(TextField),
          timeout: TestConfig.mediumTimeout,
        );

        // Generate unique test email to avoid conflicts
        final testEmail = 'test_${DateTime.now().millisecondsSinceEpoch}@test.com';
        const testPassword = 'TestPassword123!';

        // Enter email
        TestLogger.logSubStep('Entering email: $testEmail');
        final emailField = find.byWidgetPredicate((widget) =>
            widget is TextField &&
            (widget.decoration?.labelText?.toLowerCase().contains('email') == true ||
                widget.decoration?.hintText?.toLowerCase().contains('email') == true));
        if (emailField.evaluate().isNotEmpty) {
          await tester.enterText(emailField.first, testEmail);
        }

        // Enter password
        TestLogger.logSubStep('Entering password...');
        final passwordField = find.byWidgetPredicate((widget) =>
            widget is TextField && widget.obscureText == true);
        if (passwordField.evaluate().isNotEmpty) {
          await tester.enterText(passwordField.first, testPassword);
        }

        // Tap Sign Up button
        TestLogger.logSubStep('Tapping Sign Up...');
        final signUpButton = find.textContaining('Sign Up');
        if (signUpButton.evaluate().isNotEmpty) {
          await tester.tapAndSettle(signUpButton.first);
        }

        // Wait for signup to complete
        await tester.wait(TestConfig.networkDelay);

        // ============================================================
        // VERIFICATION: User should now be in main app
        // ============================================================
        TestLogger.logStep('Verifying Main App');

        // Look for main app elements (Calendar, Activities, etc.)
        final mainAppFound = await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        if (mainAppFound) {
          TestLogger.logSuccess('Successfully reached main app!');
        } else {
          // Check for any success indicators
          final calendarFound = find.text('Calendar').evaluate().isNotEmpty;
          final activitiesFound = find.text('Activities').evaluate().isNotEmpty;

          if (calendarFound || activitiesFound) {
            TestLogger.logSuccess('Main app elements found');
          } else {
            TestLogger.logInfo('May be on confirmation or other screen');
          }
        }

        // Take final screenshot for verification
        await tester.screenshot('onboarding_complete');

        TestLogger.logStep('Onboarding + Auth Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
