/// Onboarding Helper for Integration Tests
///
/// Provides a reusable function to skip through the onboarding flow
/// by filling in all required fields.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_config.dart';

/// Skip through onboarding by filling in all required fields
///
/// Onboarding flow:
/// 1. Welcome Screen → "Get Started"
/// 2. Your Profile → Gender, Birthday, Height, Weight
/// 3. Sport Preferences → Running selected, "Continue"
/// 4. Food Preferences → "Save Changes"
/// 5. Create Account → "Continue without signing in"
Future<void> skipOnboarding(WidgetTester tester) async {
  // ============================================================
  // STEP 1: Welcome Screen
  // ============================================================
  final getStarted = find.text('Get Started');
  if (getStarted.evaluate().isNotEmpty) {
    await tester.tap(getStarted.first);
    await tester.pumpAndSettle();
    await Future.delayed(TestConfig.pageTransitionDelay);
  }

  // ============================================================
  // STEP 2: Your Profile Screen
  // ============================================================
  // Check if we're on the profile screen
  final yourProfile = find.text('Your Profile');
  if (yourProfile.evaluate().isNotEmpty) {
    debugPrint('  [Onboarding] On Your Profile screen - filling required fields');

    // Select Gender (MALE is default, but tap to ensure it's selected)
    final maleOption = find.text('MALE');
    if (maleOption.evaluate().isNotEmpty) {
      await tester.tap(maleOption.first);
      await tester.pumpAndSettle();
      debugPrint('  [Onboarding] Selected MALE gender');
    }

    // Select Birthday - tap the date picker
    final birthdayField = find.text('Select your birthday');
    if (birthdayField.evaluate().isNotEmpty) {
      await tester.tap(birthdayField.first);
      await tester.pumpAndSettle();
      await Future.delayed(TestConfig.tapDelay);

      // Date picker should open - tap OK to accept default or select a date
      final okButton = find.text('OK');
      if (okButton.evaluate().isNotEmpty) {
        await tester.tap(okButton.first);
        await tester.pumpAndSettle();
        debugPrint('  [Onboarding] Selected birthday');
      }
    }

    // Enter Height (ft)
    final heightFtField = find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final hint = widget.decoration?.hintText ?? '';
        final label = widget.decoration?.labelText ?? '';
        // The field shows "ft" as hint
        return hint == 'ft' || label.toLowerCase().contains('ft');
      }
      return false;
    });

    if (heightFtField.evaluate().isNotEmpty) {
      await tester.enterText(heightFtField.first, '5');
      await tester.pumpAndSettle();
      debugPrint('  [Onboarding] Entered height feet: 5');
    }

    // Enter Height (in)
    final heightInField = find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final hint = widget.decoration?.hintText ?? '';
        final label = widget.decoration?.labelText ?? '';
        return hint == 'in' || label.toLowerCase().contains('in');
      }
      return false;
    });

    if (heightInField.evaluate().isNotEmpty) {
      await tester.enterText(heightInField.first, '10');
      await tester.pumpAndSettle();
      debugPrint('  [Onboarding] Entered height inches: 10');
    }

    // Enter Weight
    final weightField = find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final hint = widget.decoration?.hintText ?? '';
        return hint.toLowerCase().contains('weight') ||
            hint.toLowerCase().contains('enter your weight');
      }
      return false;
    });

    if (weightField.evaluate().isNotEmpty) {
      await tester.enterText(weightField.first, '150');
      await tester.pumpAndSettle();
      debugPrint('  [Onboarding] Entered weight: 150');
    }

    // Dismiss keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Scroll down to find Continue button (it may be off-screen)
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -200));
      await tester.pumpAndSettle();
    }

    // Tap Continue button
    final continueBtn = find.text('Continue');
    if (continueBtn.evaluate().isNotEmpty) {
      await tester.tap(continueBtn.first);
      await tester.pumpAndSettle();
      await Future.delayed(TestConfig.pageTransitionDelay);
      debugPrint('  [Onboarding] Tapped Continue on Profile');
    }
  }

  // ============================================================
  // STEP 3: Sport Preferences Screen
  // ============================================================
  await tester.pumpAndSettle();
  final sportPreferences = find.text('Sport Preferences');
  if (sportPreferences.evaluate().isNotEmpty) {
    debugPrint('  [Onboarding] On Sport Preferences screen');

    // RUNNING should already be selected by default
    // Just tap Continue
    final continueBtn = find.text('Continue');
    if (continueBtn.evaluate().isNotEmpty) {
      await tester.tap(continueBtn.first);
      await tester.pumpAndSettle();
      await Future.delayed(TestConfig.pageTransitionDelay);
      debugPrint('  [Onboarding] Tapped Continue on Sport Preferences');
    }
  }

  // ============================================================
  // STEP 4: Food Preferences Screen
  // ============================================================
  await tester.pumpAndSettle();
  final foodPreferences = find.text('Food Preferences');
  if (foodPreferences.evaluate().isNotEmpty) {
    debugPrint('  [Onboarding] On Food Preferences screen');

    // Scroll down to find Save Changes button
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    // Tap Save Changes
    final saveChanges = find.text('Save Changes');
    if (saveChanges.evaluate().isNotEmpty) {
      await tester.tap(saveChanges.first);
      await tester.pumpAndSettle();
      await Future.delayed(TestConfig.pageTransitionDelay);
      debugPrint('  [Onboarding] Tapped Save Changes on Food Preferences');
    }
  }

  // ============================================================
  // STEP 5: Create Account Screen
  // Wait for the screen to appear, then skip auth
  // ============================================================
  await tester.pumpAndSettle();
  await Future.delayed(TestConfig.pageTransitionDelay);
  await tester.pumpAndSettle();

  // Check for various possible screen states
  final createAccount = find.text('Create Your Account');
  final createAccountAlt = find.text('Create Account');
  final signInTitle = find.text('Sign In');
  final welcomeBack = find.text('Welcome Back');

  final isOnAuthScreen = createAccount.evaluate().isNotEmpty ||
      createAccountAlt.evaluate().isNotEmpty ||
      signInTitle.evaluate().isNotEmpty ||
      welcomeBack.evaluate().isNotEmpty;

  if (isOnAuthScreen) {
    debugPrint('  [Onboarding] On Auth/Create Account screen');

    // Try multiple possible skip options
    final skipOptions = [
      'Continue without signing in',
      'Skip',
      'Skip for now',
      'Continue as guest',
      'Not now',
    ];

    for (final option in skipOptions) {
      final skipAuth = find.text(option);
      if (skipAuth.evaluate().isNotEmpty) {
        await tester.tap(skipAuth.first);
        await tester.pumpAndSettle();
        await Future.delayed(TestConfig.pageTransitionDelay);
        debugPrint('  [Onboarding] Tapped: $option');
        break;
      }
    }
  } else {
    // The user might already be authenticated (anonymous) and go directly to main app
    debugPrint('  [Onboarding] Auth screen not found - user may already be authenticated');
  }

  // Final wait for navigation to complete
  await tester.pumpAndSettle();
  await Future.delayed(TestConfig.networkDelay);
  await tester.pumpAndSettle();

  debugPrint('  [Onboarding] Onboarding complete!');
}

/// Alternative: Skip onboarding for a user who already has data
/// This can be used when testing with a pre-existing test account
Future<void> skipOnboardingIfPresent(WidgetTester tester) async {
  // Check if we're on welcome screen
  if (find.text('Get Started').evaluate().isNotEmpty) {
    await skipOnboarding(tester);
  }
}
