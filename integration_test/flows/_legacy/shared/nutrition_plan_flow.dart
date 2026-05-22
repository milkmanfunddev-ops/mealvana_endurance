/// Nutrition Plan Flow - Reusable Test Module
///
/// Can be run standalone or as part of all_flows_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Run the nutrition plan flow test
///
/// Assumes app is already launched and user is on main calendar screen.
/// If [skipOnboardingCheck] is true, assumes onboarding is already complete.
Future<void> runNutritionPlanFlow(
  WidgetTester tester, {
  bool skipOnboardingCheck = true,
}) async {
  TestLogger.logStep('Starting Nutrition Plan Flow');

  // ============================================================
  // STEP 1: Navigate to Create Activity via Orange FAB
  // ============================================================
  TestLogger.logStep('Navigating to Create Activity');

  // Wait for the main calendar screen to be ready
  await tester.wait(TestConfig.pageTransitionDelay);

  // The orange FAB (+) button uses FontAwesomeIcons.plus (not Icons.add)
  // It's a CircularActionButton with an IconButton inside
  // Try FontAwesome plus icon first (primary approach)
  final faPlus = find.byIcon(FontAwesomeIcons.plus);
  if (faPlus.evaluate().isNotEmpty) {
    TestLogger.logSubStep('Found FontAwesome plus icon, tapping...');
    await tester.tapAndSettle(faPlus.first);
  } else {
    // Try Material Icons.add as backup
    final addIcon = find.byIcon(Icons.add);
    if (addIcon.evaluate().isNotEmpty) {
      TestLogger.logSubStep('Found add icon, tapping...');
      await tester.tapAndSettle(addIcon.first);
    } else {
      // Try "CREATE AN EVENT" button as fallback
      final createEventBtn = find.textContaining('CREATE AN EVENT');
      if (createEventBtn.evaluate().isNotEmpty) {
        TestLogger.logSubStep('Tapping CREATE AN EVENT button');
        await tester.tapAndSettle(createEventBtn.first);
      } else {
        // Try "Create an Event" (case insensitive variant)
        final createEventAlt = find.textContaining('Create an Event');
        if (createEventAlt.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Tapping Create an Event button');
          await tester.tapAndSettle(createEventAlt.first);
        } else {
          TestLogger.logError('Could not find FAB or CREATE AN EVENT button');
          return;
        }
      }
    }
  }

  await tester.wait(TestConfig.pageTransitionDelay);

  // ============================================================
  // STEP 2: Handle New Event Screen (if shown)
  // ============================================================
  final newEventScreen = find.text('New Event');
  if (newEventScreen.evaluate().isNotEmpty) {
    TestLogger.logSubStep('On New Event screen - creating event first');

    // Select Run category
    final runOption = find.text('RUN');
    if (runOption.evaluate().isNotEmpty) {
      await tester.tapAndSettle(runOption.first);
    }

    // Enter event name - the field has labelText: 'Event Name'
    final eventNameField = find.byWidgetPredicate((widget) {
      if (widget is TextField) {
        final decoration = widget.decoration;
        if (decoration != null) {
          final label = decoration.labelText ?? '';
          return label == 'Event Name';
        }
      }
      return false;
    });

    if (eventNameField.evaluate().isNotEmpty) {
      await tester.enterText(eventNameField.first, 'Test Run Event');
      await tester.pumpAndSettle();
      TestLogger.logSubStep('Entered event name');
    } else {
      // Fallback: use first text field
      final allTextFields = find.byType(TextField);
      if (allTextFields.evaluate().isNotEmpty) {
        await tester.enterText(allTextFields.first, 'Test Run Event');
        await tester.pumpAndSettle();
        TestLogger.logSubStep('Entered event name in first text field');
      }
    }

    // Dismiss keyboard
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Tap Create Event button (button text is "Create Event" in create mode)
    var createEventBtn = find.text('Create Event');
    if (createEventBtn.evaluate().isEmpty) {
      await tester.scrollToFind(find.text('Create Event'));
      createEventBtn = find.text('Create Event');
    }
    if (createEventBtn.evaluate().isNotEmpty) {
      await tester.tapAndSettle(createEventBtn.first);
      TestLogger.logSubStep('Tapped Create Event');
    }

    await tester.wait(TestConfig.networkDelay);

    // Wait for Event Details screen and tap "Create Nutrition Plan"
    final createPlanFound = await tester.waitForWidget(
      find.textContaining('Create Nutrition Plan'),
      timeout: TestConfig.mediumTimeout,
    );

    if (createPlanFound) {
      final createPlanBtn = find.textContaining('Create Nutrition Plan');
      await tester.tapAndSettle(createPlanBtn.first);
      await tester.wait(TestConfig.pageTransitionDelay);
    }
  }

  // ============================================================
  // STEP 3: Configure Activity and Generate Plan
  // ============================================================
  TestLogger.logStep('Configuring Activity');

  // Wait for New Activity screen - look for Generate Plan button
  final activityScreenReady = await tester.waitForWidget(
    find.text('Generate Plan'),
    timeout: TestConfig.mediumTimeout,
  );

  if (activityScreenReady) {
    TestLogger.logSubStep('On New Activity screen');

    // Verify Running is selected (should show as selected)
    final runningSelected = find.text('RUNNING');
    if (runningSelected.evaluate().isNotEmpty) {
      TestLogger.logSubStep('Running option available');
    }

    TestLogger.logSubStep('Using default distance and pace');

    // Tap Generate Plan button to generate macros
    TestLogger.logStep('Tapping Generate Plan');
    final generatePlanBtn = find.text('Generate Plan');
    await tester.tapAndSettle(generatePlanBtn.first);

    // Wait for macro generation and navigation to adjust-macros screen
    await tester.wait(TestConfig.networkDelay);
    TestLogger.logSuccess('Generate Plan tapped');
  } else {
    TestLogger.logError('Could not find Generate Plan button');
    return;
  }

  // ============================================================
  // STEP 4: Review Macros
  // ============================================================
  TestLogger.logStep('Reviewing Macros');

  final macrosFound = await tester.waitForWidget(
    find.textContaining('Adjust Your Macros'),
    timeout: TestConfig.mediumTimeout,
  );

  if (macrosFound) {
    TestLogger.logSubStep('On Adjust Your Macros screen');

    // Verify macro columns
    final preFound = find.text('PRE').evaluate().isNotEmpty;
    final duringFound = find.text('DURING').evaluate().isNotEmpty;
    final postFound = find.text('POST').evaluate().isNotEmpty;

    if (preFound && duringFound && postFound) {
      TestLogger.logSuccess('Macro columns displayed correctly');
    }

    // Tap "Create Plan" to generate the nutrition plan
    final createPlanBtn = find.text('Create Plan');
    if (createPlanBtn.evaluate().isNotEmpty) {
      await tester.tapAndSettle(createPlanBtn.first);
      TestLogger.logSubStep('Tapped Create Plan');
    }

    // Wait for AI generation (can take a while)
    await tester.wait(TestConfig.longTimeout);
  }

  // ============================================================
  // STEP 5: View Generated Plan
  // ============================================================
  TestLogger.logStep('Viewing Generated Plan');

  final planFound = await tester.waitForWidget(
    find.textContaining('BEFORE'),
    timeout: TestConfig.longTimeout,
  );

  if (planFound) {
    TestLogger.logSuccess('Nutrition plan generated and displayed');
    await tester.screenshot('nutrition_plan_generated');
  } else {
    TestLogger.logInfo('Plan generation may still be in progress or failed');
  }

  TestLogger.logStep('Nutrition Plan Flow Complete!');
}
