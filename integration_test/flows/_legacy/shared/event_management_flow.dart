/// Event Management Flow - Reusable Test Module
///
/// Can be run standalone or as part of all_flows_test.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../helpers/test_config.dart';
import '../../helpers/test_helpers.dart';

/// Run the event management flow test
///
/// Assumes app is already launched and user is on main activities list screen.
///
/// Navigation Flow (based on UpcomingEventCardKyle):
/// - No events: Card shows "Create an Event" → tapping goes to EventFormScreen ("New Event")
/// - Event exists: Card shows event name → tapping goes to EventDetailScreen ("Event Details")
///   → scroll to footer and tap "Create new event" to go to EventFormScreen
Future<void> runEventManagementFlow(WidgetTester tester) async {
  TestLogger.logStep('Starting Event Management Flow');

  // ============================================================
  // STEP 1: Ensure We're on Activities List Screen
  // ============================================================
  TestLogger.logStep('Verifying Activities List Screen');

  // Wait for the screen to load
  await tester.pumpAndSettle();
  await tester.wait(TestConfig.pageTransitionDelay);

  // Look for the "Upcoming Events" section header - this confirms we're on activities list
  final upcomingEventsHeader = find.text('Upcoming Events');
  final headerFound = await tester.waitForWidget(
    upcomingEventsHeader,
    timeout: TestConfig.mediumTimeout,
  );

  if (headerFound) {
    TestLogger.logSubStep('Found Upcoming Events section header');
  } else {
    TestLogger.logInfo('Upcoming Events header not visible, may need to scroll');
  }

  // ============================================================
  // STEP 2: Navigate to Event Creation
  // ============================================================
  TestLogger.logStep('Navigating to Event Creation');

  // Check for "Create an Event" text (shown when no events exist)
  final createAnEventCard = find.text('Create an Event');

  if (createAnEventCard.evaluate().isNotEmpty) {
    // No events exist - tap the "Create an Event" card
    TestLogger.logSubStep('No events exist - tapping "Create an Event" card');
    await tester.tapAndSettle(createAnEventCard.first);
  } else {
    // An event exists - we need to go through Event Details screen
    TestLogger.logSubStep('Event exists - tapping event card to go to Event Details');

    // First, try tapping the Upcoming Events header area (the whole section might be tappable)
    if (upcomingEventsHeader.evaluate().isNotEmpty) {
      // Look for any text below "Upcoming Events" that might be the event card
      // The UpcomingEventCardKyle shows event name, countdown, etc.
      await tester.tapAndSettle(upcomingEventsHeader.first);
      await tester.wait(TestConfig.pageTransitionDelay);
    }

    // Check if we're on Event Details screen
    final eventDetailsScreen = find.text('Event Details');
    if (eventDetailsScreen.evaluate().isNotEmpty) {
      TestLogger.logSubStep('On Event Details screen - looking for Create new event link');

      // Scroll to find "Create new event" link at the bottom
      await tester.scrollToFind(find.text('Create new event'));

      final createNewEventLink = find.text('Create new event');
      if (createNewEventLink.evaluate().isNotEmpty) {
        await tester.tapAndSettle(createNewEventLink.first);
        TestLogger.logSubStep('Tapped Create new event link');
      }
    } else {
      // Fallback: use the orange FAB to create an event
      TestLogger.logInfo('Using orange FAB as fallback');
      final faPlus = find.byIcon(FontAwesomeIcons.plus);
      if (faPlus.evaluate().isNotEmpty) {
        await tester.tapAndSettle(faPlus.first);
      }
    }
  }

  await tester.pumpAndSettle();
  await tester.wait(TestConfig.pageTransitionDelay);

  // ============================================================
  // STEP 3: Fill Event Form (EventFormScreen - "New Event")
  // ============================================================
  TestLogger.logStep('Filling Event Form');

  // Wait for "New Event" screen (EventFormScreen title)
  final newEventFound = await tester.waitForWidget(
    find.text('New Event'),
    timeout: TestConfig.mediumTimeout,
  );

  if (!newEventFound) {
    TestLogger.logError('Could not navigate to New Event screen');
    return;
  }

  TestLogger.logSubStep('On New Event screen');

  // Select RUN sport category (should be first option)
  final runCategory = find.text('RUN');
  if (runCategory.evaluate().isNotEmpty) {
    await tester.tapAndSettle(runCategory.first);
    TestLogger.logSubStep('Selected RUN category');
  }

  // Enter Event Name - the field has labelText: 'Event Name'
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
    await tester.enterText(eventNameField.first, TestConfig.testEvent.name);
    await tester.pumpAndSettle();
    TestLogger.logSubStep('Entered event name: ${TestConfig.testEvent.name}');
  } else {
    // Fallback: try entering in first text field
    final allTextFields = find.byType(TextField);
    if (allTextFields.evaluate().isNotEmpty) {
      await tester.enterText(allTextFields.first, TestConfig.testEvent.name);
      await tester.pumpAndSettle();
      TestLogger.logSubStep('Entered event name in first text field');
    }
  }

  // Enter Location (optional) - the field has labelText: 'Location (optional)'
  final locationField = find.byWidgetPredicate((widget) {
    if (widget is TextField) {
      final decoration = widget.decoration;
      if (decoration != null) {
        final label = decoration.labelText ?? '';
        return label.contains('Location');
      }
    }
    return false;
  });

  if (locationField.evaluate().isNotEmpty) {
    await tester.enterText(locationField.first, TestConfig.testEvent.location);
    await tester.pumpAndSettle();
    TestLogger.logSubStep('Entered location: ${TestConfig.testEvent.location}');
  }

  // Dismiss keyboard if open
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  // ============================================================
  // STEP 4: Save Event
  // ============================================================
  TestLogger.logStep('Saving Event');

  // The save button shows "Create Event" in create mode
  var createEventBtn = find.text('Create Event');

  if (createEventBtn.evaluate().isEmpty) {
    // Try scrolling to find it
    TestLogger.logSubStep('Scrolling to find Create Event button...');
    await tester.scrollToFind(find.text('Create Event'));
    createEventBtn = find.text('Create Event');
  }

  if (createEventBtn.evaluate().isNotEmpty) {
    await tester.tapAndSettle(createEventBtn.first);
    TestLogger.logSuccess('Tapped Create Event');
  } else {
    TestLogger.logError('Could not find Create Event button');
    return;
  }

  await tester.wait(TestConfig.networkDelay);

  // ============================================================
  // STEP 5: Verify Event Created - Should be on Event Details
  // ============================================================
  TestLogger.logStep('Verifying Event Created');

  // After creation, the app navigates back - we might be on Event Details or Activities List
  final eventDetailsFound = await tester.waitForWidget(
    find.text('Event Details'),
    timeout: TestConfig.mediumTimeout,
  );

  if (eventDetailsFound) {
    TestLogger.logSubStep('On Event Details screen - event created successfully');

    // Verify event name is displayed
    final eventNameDisplayed = find.textContaining(TestConfig.testEvent.name);
    if (eventNameDisplayed.evaluate().isNotEmpty) {
      TestLogger.logSuccess('Event name displayed correctly');
    }

    // Verify nutrition planning buttons are visible
    final createNutritionPlanBtn = find.textContaining('Create Nutrition Plan');
    if (createNutritionPlanBtn.evaluate().isNotEmpty) {
      TestLogger.logSubStep('Create Nutrition Plan button visible');
    }

    final carbLoadingBtn = find.textContaining('Carb Loading');
    if (carbLoadingBtn.evaluate().isNotEmpty) {
      TestLogger.logSubStep('Carb Loading button visible');
    }

    await tester.screenshot('event_created');

    // ============================================================
    // STEP 6: Navigate Back to Activities List
    // ============================================================
    TestLogger.logStep('Navigating Back');

    final backBtn = find.byIcon(Icons.arrow_back);
    if (backBtn.evaluate().isNotEmpty) {
      await tester.tapAndSettle(backBtn.first);
      await tester.wait(TestConfig.pageTransitionDelay);
    }
  } else {
    // We might already be back on Activities List
    TestLogger.logInfo('May have returned to Activities List directly');
  }

  // Verify we're back on activities list
  final backOnActivities = find.text('Upcoming Events').evaluate().isNotEmpty ||
      find.byIcon(FontAwesomeIcons.plus).evaluate().isNotEmpty;

  if (backOnActivities) {
    TestLogger.logSuccess('Back on Activities List screen');
  }

  await tester.screenshot('event_management_complete');
  TestLogger.logStep('Event Management Flow Complete!');
}
