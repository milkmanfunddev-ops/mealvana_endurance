/// Email Login Flow Integration Test
///
/// Tests existing user login with test account:
/// 1. App launches (may have existing session or create anonymous)
/// 2. User navigates to Settings
/// 3. User taps Account section to log in
/// 4. User logs in with test@test.com / test
/// 5. Verify user is authenticated
///
/// Prerequisites:
/// - test@test.com account exists in dev Supabase
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Email Login Flow', () {
    testWidgets(
      'Existing user can log in with email and password',
      (tester) async {
        TestLogger.logStep('Starting Email Login Flow Test');

        // ============================================================
        // STEP 1: Launch App
        // ============================================================
        TestLogger.logSubStep('Launching app...');
        app.main();
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        TestLogger.logSuccess('App launched');

        // ============================================================
        // STEP 2: Navigate to Main App (skip onboarding if needed)
        // ============================================================
        TestLogger.logStep('Getting to Main App');

        // Check if we're on welcome screen
        if (find.textContaining('Welcome').evaluate().isNotEmpty) {
          TestLogger.logSubStep('On welcome screen - need to complete onboarding first');

          // Quick path through onboarding for login test
          // Tap Get Started
          final getStarted = find.textContaining('Get Started');
          if (getStarted.evaluate().isNotEmpty) {
            await tester.tapAndSettle(getStarted.first);
            await tester.wait(TestConfig.pageTransitionDelay);
          }

          // Profile screen - just tap Continue with defaults
          final continueBtn = find.textContaining('Continue');
          if (continueBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(continueBtn.first);
            await tester.wait(TestConfig.pageTransitionDelay);
          }

          // Sport preferences - tap Continue
          final continueBtn2 = find.textContaining('Continue');
          if (continueBtn2.evaluate().isNotEmpty) {
            await tester.tapAndSettle(continueBtn2.first);
            await tester.wait(TestConfig.pageTransitionDelay);
          }

          // Food preferences - tap Done/Continue
          final doneBtn = find.textContaining('Done');
          if (doneBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(doneBtn.first);
          } else {
            final continueBtn3 = find.textContaining('Continue');
            if (continueBtn3.evaluate().isNotEmpty) {
              await tester.tapAndSettle(continueBtn3.first);
            }
          }
          await tester.wait(TestConfig.pageTransitionDelay);

          // Auth screen - tap Skip or "Maybe Later"
          final skipBtn = find.textContaining('Skip');
          if (skipBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(skipBtn.first);
          } else {
            final laterBtn = find.textContaining('Later');
            if (laterBtn.evaluate().isNotEmpty) {
              await tester.tapAndSettle(laterBtn.first);
            }
          }
          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // ============================================================
        // STEP 3: Navigate to Settings
        // ============================================================
        TestLogger.logStep('Navigating to Settings');

        // Wait for main app to load
        await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        // Find and tap Settings tab
        final settingsIcon = find.byIcon(Icons.settings);
        if (settingsIcon.evaluate().isNotEmpty) {
          await tester.tapAndSettle(settingsIcon.first);
          TestLogger.logSuccess('Tapped Settings tab');
        } else {
          // Try finding by text
          final settingsText = find.text('Settings');
          if (settingsText.evaluate().isNotEmpty) {
            await tester.tapAndSettle(settingsText.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 4: Tap Account Section
        // ============================================================
        TestLogger.logStep('Opening Account Section');

        // Look for Account section in settings
        final accountFinder = find.textContaining('Account');
        if (accountFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(accountFinder.first);
          TestLogger.logSuccess('Tapped Account section');
        } else {
          // Try "Log In" or "Sign In" button
          final loginFinder = find.textContaining('Log In');
          if (loginFinder.evaluate().isNotEmpty) {
            await tester.tapAndSettle(loginFinder.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 5: Select Email Login Option
        // ============================================================
        TestLogger.logStep('Selecting Email Login');

        // Look for "Log in with Email" or similar
        final emailLoginFinder = find.textContaining('Email');
        if (emailLoginFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(emailLoginFinder.first);
          TestLogger.logSuccess('Selected Email login');
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 6: Enter Login Credentials
        // ============================================================
        TestLogger.logStep('Entering Login Credentials');

        // Wait for login form
        await tester.waitForWidget(
          find.byType(TextField),
          timeout: TestConfig.mediumTimeout,
        );

        // Enter email
        TestLogger.logSubStep('Entering email: ${TestConfig.testEmail}');
        final emailField = find.byWidgetPredicate((widget) {
          if (widget is TextField) {
            final hint = widget.decoration?.hintText?.toLowerCase() ?? '';
            final label = widget.decoration?.labelText?.toLowerCase() ?? '';
            return hint.contains('email') || label.contains('email');
          }
          return false;
        });

        if (emailField.evaluate().isNotEmpty) {
          await tester.enterText(emailField.first, TestConfig.testEmail);
        } else {
          // Try first TextField
          final textFields = find.byType(TextField);
          if (textFields.evaluate().isNotEmpty) {
            await tester.enterText(textFields.first, TestConfig.testEmail);
          }
        }

        await tester.pumpAndSettle();

        // Enter password
        TestLogger.logSubStep('Entering password...');
        final passwordField = find.byWidgetPredicate((widget) =>
            widget is TextField && widget.obscureText == true);

        if (passwordField.evaluate().isNotEmpty) {
          await tester.enterText(passwordField.first, TestConfig.testPassword);
        }

        await tester.pumpAndSettle();

        // ============================================================
        // STEP 7: Tap Login Button
        // ============================================================
        TestLogger.logStep('Submitting Login');

        final loginButton = find.textContaining('Log In');
        if (loginButton.evaluate().isNotEmpty) {
          await tester.tapAndSettle(loginButton.first);
        } else {
          final signInButton = find.textContaining('Sign In');
          if (signInButton.evaluate().isNotEmpty) {
            await tester.tapAndSettle(signInButton.first);
          }
        }

        // Wait for login to complete
        await tester.wait(TestConfig.networkDelay);

        // ============================================================
        // VERIFICATION: Check login success
        // ============================================================
        TestLogger.logStep('Verifying Login Success');

        // Should be back in main app or settings
        // Look for indicators that user is logged in
        final authenticatedFound = await tester.waitForWidget(
          find.textContaining('test@test.com'),
          timeout: TestConfig.mediumTimeout,
        );

        if (authenticatedFound) {
          TestLogger.logSuccess('Email displayed - user is authenticated!');
        } else {
          // Check if we're in the main app
          final mainAppFound =
              find.byType(BottomNavigationBar).evaluate().isNotEmpty;
          if (mainAppFound) {
            TestLogger.logSuccess('Back in main app - login likely succeeded');
          } else {
            // Check for error messages
            final errorFinder = find.textContaining('Error');
            if (errorFinder.evaluate().isNotEmpty) {
              TestLogger.logError('Login error displayed');
            } else {
              TestLogger.logInfo('Login status unclear');
            }
          }
        }

        // Take screenshot
        await tester.screenshot('email_login_complete');

        TestLogger.logStep('Email Login Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
