/// Email Authentication Flow
///
/// Tests email login and logout functionality:
/// 1. Navigate to Settings
/// 2. Find and tap "Log In" or email login option
/// 3. Enter test credentials (test@test.com / test)
/// 4. Verify login success
/// 5. Navigate to Settings
/// 6. Tap Sign Out
/// 7. Confirm sign out dialog
/// 8. Verify we're back at Welcome screen
///
/// FAIL-FAST: Any step that fails will capture screenshot and throw
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Run the email login flow
/// Returns true if login was successful
Future<bool> runEmailLoginFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Email Login Flow');

  // ============================================================
  // STEP 1: Navigate to Settings
  // ============================================================
  TestLogger.logSubStep('Navigating to Settings for login...');

  // Tap the ellipsis (menu) icon to go to Settings
  final menuIcon = find.byIcon(FontAwesomeIcons.ellipsis);
  if (menuIcon.evaluate().isEmpty) {
    await tester.screenshot('FAIL_email_login_no_menu_icon');
    throw TestFailure('FAIL: Could not find menu icon to navigate to Settings');
  }

  await tester.tapAndSettle(menuIcon.first);
  await tester.wait(TestConfig.pageTransitionDelay);

  // Verify we're on Settings screen
  final settingsTitle = find.text('Settings');
  if (settingsTitle.evaluate().isEmpty) {
    await tester.screenshot('FAIL_email_login_not_on_settings');
    throw TestFailure('FAIL: Not on Settings screen after tapping menu');
  }

  TestLogger.logSuccess('On Settings screen');

  // ============================================================
  // STEP 2: Find and tap Log In option
  // ============================================================
  TestLogger.logSubStep('Looking for Log In option...');

  // Scroll to find the login option if needed
  final scrollable = find.byType(Scrollable);
  bool foundLoginOption = false;

  // Try to find various login text options
  final loginTexts = ['Log In', 'Sign In', 'Login', 'Account'];

  for (final text in loginTexts) {
    final loginOption = find.text(text);
    if (loginOption.evaluate().isNotEmpty) {
      await tester.tapAndSettle(loginOption.first);
      foundLoginOption = true;
      TestLogger.logSubStep('Tapped: $text');
      break;
    }
  }

  if (!foundLoginOption) {
    // Try scrolling down to find it
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 5; i++) {
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pumpAndSettle();

        for (final text in loginTexts) {
          final loginOption = find.text(text);
          if (loginOption.evaluate().isNotEmpty) {
            await tester.tapAndSettle(loginOption.first);
            foundLoginOption = true;
            TestLogger.logSubStep('Found and tapped: $text after scrolling');
            break;
          }
        }
        if (foundLoginOption) break;
      }
    }
  }

  if (!foundLoginOption) {
    await tester.screenshot('FAIL_email_login_no_login_option');
    throw TestFailure(
      'FAIL: Could not find Log In option on Settings screen. '
      'User may already be logged in or UI has changed.',
    );
  }

  await tester.wait(TestConfig.pageTransitionDelay);

  // ============================================================
  // STEP 3: Select Email login (if on auth options screen)
  // ============================================================
  // Check if we're on an auth options screen with multiple login methods
  final emailOption = find.textContaining('Email');
  if (emailOption.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Selecting Email login option...');
    await tester.tapAndSettle(emailOption.first);
    await tester.wait(TestConfig.pageTransitionDelay);
  }

  // ============================================================
  // STEP 4: Enter credentials
  // ============================================================
  TestLogger.logSubStep('Entering login credentials...');

  // Wait for email field to appear
  final emailFieldFound = await tester.waitForWidget(
    find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final hint = widget.decoration?.hintText?.toLowerCase() ?? '';
        final label = widget.decoration?.labelText?.toLowerCase() ?? '';
        return hint.contains('email') || label.contains('email');
      }
      return false;
    }),
    timeout: TestConfig.mediumTimeout,
  );

  if (!emailFieldFound) {
    // Try to find any TextField
    final anyTextField = find.byType(TextField);
    if (anyTextField.evaluate().isEmpty) {
      await tester.screenshot('FAIL_email_login_no_email_field');
      throw TestFailure('FAIL: Could not find email input field');
    }
  }

  // Enter email
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
    // Use first text field
    final firstField = find.byType(TextField).first;
    await tester.enterText(firstField, TestConfig.testEmail);
  }
  await tester.pumpAndSettle();
  TestLogger.logSubStep('Entered email: ${TestConfig.testEmail}');

  // Enter password
  final passwordField = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.obscureText == true,
  );

  if (passwordField.evaluate().isEmpty) {
    await tester.screenshot('FAIL_email_login_no_password_field');
    throw TestFailure('FAIL: Could not find password input field');
  }

  await tester.enterText(passwordField.first, TestConfig.testPassword);
  await tester.pumpAndSettle();
  TestLogger.logSubStep('Entered password');

  // ============================================================
  // STEP 5: Tap Login button
  // ============================================================
  TestLogger.logSubStep('Tapping Log In button...');

  final loginButton = find.text('Log In');
  if (loginButton.evaluate().isEmpty) {
    final signInButton = find.text('Sign In');
    if (signInButton.evaluate().isEmpty) {
      await tester.screenshot('FAIL_email_login_no_login_button');
      throw TestFailure('FAIL: Could not find Log In or Sign In button');
    }
    await tester.tapAndSettle(signInButton.first);
  } else {
    await tester.tapAndSettle(loginButton.first);
  }

  // Wait for network request
  await tester.wait(TestConfig.networkDelay);
  await tester.wait(TestConfig.networkDelay); // Extra wait for auth

  // ============================================================
  // STEP 6: Verify login success
  // ============================================================
  TestLogger.logSubStep('Verifying login success...');

  // Check for success indicators:
  // 1. Back in main app (calendar icon visible)
  // 2. Success snackbar
  // 3. Email displayed somewhere

  bool loginSuccess = false;

  // Wait for navigation back to main app
  final endTime = DateTime.now().add(TestConfig.mediumTimeout);
  while (DateTime.now().isBefore(endTime) && !loginSuccess) {
    await tester.pump(const Duration(milliseconds: 500));

    // Check for main app indicators
    final hasCalendar =
        find.byIcon(FontAwesomeIcons.calendar).evaluate().isNotEmpty;
    final hasEmail =
        find.textContaining(TestConfig.testEmail).evaluate().isNotEmpty;
    final hasSuccessSnackbar =
        find.textContaining('success').evaluate().isNotEmpty ||
            find.textContaining('Logged in').evaluate().isNotEmpty;

    // Check for error indicators
    final hasError = find.textContaining('Error').evaluate().isNotEmpty ||
        find.textContaining('failed').evaluate().isNotEmpty ||
        find.textContaining('Invalid').evaluate().isNotEmpty;

    if (hasError) {
      await tester.screenshot('FAIL_email_login_error');
      throw TestFailure(
        'FAIL: Login error displayed. Check credentials or network.',
      );
    }

    if (hasCalendar || hasEmail || hasSuccessSnackbar) {
      loginSuccess = true;
      TestLogger.logSubStep(
        'Login verified: Calendar=$hasCalendar, Email=$hasEmail, Success=$hasSuccessSnackbar',
      );
    }
  }

  if (!loginSuccess) {
    await tester.screenshot('FAIL_email_login_timeout');
    throw TestFailure(
      'FAIL: Login did not complete within timeout. '
      'Could not verify successful authentication.',
    );
  }

  await tester.pumpAndSettle();
  await tester.screenshot('email_login_success');

  TestLogger.logSuccess('Email Login Flow: PASSED');
  return true;
}

/// Run the logout flow
/// Returns true if logout was successful and we're back at Welcome screen
Future<bool> runLogoutFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Logout Flow');

  // ============================================================
  // STEP 1: Navigate to Settings
  // ============================================================
  TestLogger.logSubStep('Navigating to Settings for logout...');

  // Tap the ellipsis (menu) icon to go to Settings
  final menuIcon = find.byIcon(FontAwesomeIcons.ellipsis);
  if (menuIcon.evaluate().isEmpty) {
    await tester.screenshot('FAIL_logout_no_menu_icon');
    throw TestFailure('FAIL: Could not find menu icon to navigate to Settings');
  }

  await tester.tapAndSettle(menuIcon.first);
  await tester.wait(TestConfig.pageTransitionDelay);

  // Verify we're on Settings screen
  final settingsTitle = find.text('Settings');
  if (settingsTitle.evaluate().isEmpty) {
    await tester.screenshot('FAIL_logout_not_on_settings');
    throw TestFailure('FAIL: Not on Settings screen after tapping menu');
  }

  TestLogger.logSuccess('On Settings screen');

  // ============================================================
  // STEP 2: Find and tap Sign Out button
  // ============================================================
  TestLogger.logSubStep('Looking for Sign Out button...');

  // Scroll to find Sign Out button
  final scrollable = find.byType(Scrollable);
  bool foundSignOut = false;

  // First check without scrolling
  final signOutButton = find.text('Sign Out');
  if (signOutButton.evaluate().isNotEmpty) {
    foundSignOut = true;
  } else {
    // Scroll down to find it
    if (scrollable.evaluate().isNotEmpty) {
      for (var i = 0; i < 8; i++) {
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pumpAndSettle();

        if (find.text('Sign Out').evaluate().isNotEmpty) {
          foundSignOut = true;
          TestLogger.logSubStep('Found Sign Out after scrolling');
          break;
        }
      }
    }
  }

  if (!foundSignOut) {
    await tester.screenshot('FAIL_logout_no_sign_out_button');
    throw TestFailure(
      'FAIL: Could not find Sign Out button. '
      'User may not be logged in or UI has changed.',
    );
  }

  // Tap Sign Out
  await tester.tapAndSettle(find.text('Sign Out').first);
  await tester.wait(TestConfig.tapDelay);

  // ============================================================
  // STEP 3: Confirm sign out dialog
  // ============================================================
  TestLogger.logSubStep('Confirming sign out dialog...');

  // Look for confirmation dialog
  final confirmDialog = find.text('Sign Out?');
  if (confirmDialog.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Confirmation dialog appeared');

    // Find and tap the confirm button in the dialog
    // The dialog has Cancel and Sign Out buttons
    final dialogSignOut = find.text('Sign Out');
    if (dialogSignOut.evaluate().length > 1) {
      // Tap the last one (the dialog button, not the settings button behind)
      await tester.tapAndSettle(dialogSignOut.last);
    } else if (dialogSignOut.evaluate().isNotEmpty) {
      await tester.tapAndSettle(dialogSignOut.first);
    }
  } else {
    TestLogger.logSubStep('No confirmation dialog - sign out may have proceeded');
  }

  // Wait for sign out to complete
  await tester.wait(TestConfig.networkDelay);

  // ============================================================
  // STEP 4: Verify we're back at Welcome screen
  // ============================================================
  TestLogger.logSubStep('Verifying logout - expecting Welcome screen...');

  bool logoutSuccess = false;
  final endTime = DateTime.now().add(TestConfig.mediumTimeout);

  while (DateTime.now().isBefore(endTime) && !logoutSuccess) {
    await tester.pump(const Duration(milliseconds: 500));

    // Check for Welcome screen indicators
    final hasGetStarted = find.text('Get Started').evaluate().isNotEmpty;
    final hasWelcome = find.textContaining('Welcome').evaluate().isNotEmpty;
    final hasMealvana = find.textContaining('Mealvana').evaluate().isNotEmpty;

    if (hasGetStarted || hasWelcome) {
      logoutSuccess = true;
      TestLogger.logSubStep(
        'Welcome screen detected: GetStarted=$hasGetStarted, Welcome=$hasWelcome, Mealvana=$hasMealvana',
      );
    }
  }

  if (!logoutSuccess) {
    await tester.screenshot('FAIL_logout_not_at_welcome');
    throw TestFailure(
      'FAIL: After logout, expected Welcome screen but did not find it. '
      'Sign out may have failed or navigation issue.',
    );
  }

  await tester.pumpAndSettle();
  await tester.screenshot('logout_success');

  TestLogger.logSuccess('Logout Flow: PASSED');
  return true;
}

/// Combined flow: Login with email, then logout
/// This tests the complete authentication cycle
Future<void> runEmailAuthCycleFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Email Auth Cycle Flow (Login + Logout)');

  // Run login flow
  final loginSuccess = await runEmailLoginFlow(tester);
  if (!loginSuccess) {
    throw TestFailure('Email login failed - cannot proceed with logout test');
  }

  // Brief pause between login and logout
  await tester.wait(TestConfig.pageTransitionDelay);

  // Run logout flow
  final logoutSuccess = await runLogoutFlow(tester);
  if (!logoutSuccess) {
    throw TestFailure('Logout failed after successful login');
  }

  TestLogger.logSuccess('Email Auth Cycle Flow: PASSED');
  TestLogger.logInfo('Successfully logged in and logged out with email');
}
