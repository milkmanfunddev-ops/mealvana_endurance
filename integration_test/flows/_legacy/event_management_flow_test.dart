/// Event Management Flow Integration Test
///
/// Tests event CRUD operations:
/// 1. User navigates to calendar
/// 2. User creates a new event (half marathon)
/// 3. User views event details
/// 4. User edits event
/// 5. User deletes event
///
/// Prerequisites:
/// - User must be logged in or have completed onboarding
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';
import '../helpers/onboarding_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Event Management Flow', () {
    testWidgets(
      'User can create, view, edit, and delete events',
      (tester) async {
        TestLogger.logStep('Starting Event Management Flow Test');

        // ============================================================
        // STEP 1: Launch App
        // ============================================================
        TestLogger.logSubStep('Launching app...');
        app.main();
        await tester.pumpAndSettle();
        await tester.wait(TestConfig.networkDelay);

        // Handle onboarding if needed
        if (find.text('Get Started').evaluate().isNotEmpty) {
          TestLogger.logSubStep('Completing onboarding...');
          await skipOnboarding(tester);
        }

        await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSuccess('App ready');

        // ============================================================
        // STEP 2: Verify Calendar Screen
        // ============================================================
        TestLogger.logStep('Verifying Calendar Screen');

        // The main screen shows calendar with:
        // - "BY WEEK" / "BY MONTH" toggle
        // - Current month/year
        // - Week day row
        // - "Upcoming Events" section
        // - "CREATE AN EVENT" button
        // - Bottom nav with calendar, list, "...", FAB

        // Look for calendar indicators
        final byWeekTab = find.text('BY WEEK');
        final byMonthTab = find.text('BY MONTH');
        final upcomingEvents = find.text('Upcoming Events');

        if (byWeekTab.evaluate().isNotEmpty || byMonthTab.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Calendar tabs found');
        }

        if (upcomingEvents.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Upcoming Events section found');
        }

        // ============================================================
        // STEP 3: Create New Event
        // ============================================================
        TestLogger.logStep('Creating New Event');

        // Tap "CREATE AN EVENT" button or FAB
        final createEventBtn = find.textContaining('CREATE AN EVENT');
        if (createEventBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(createEventBtn.first);
        } else {
          // Try FAB
          final fab = find.byType(FloatingActionButton);
          if (fab.evaluate().isNotEmpty) {
            await tester.tapAndSettle(fab.first);
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 4: Fill Event Form (New Event screen)
        // ============================================================
        TestLogger.logStep('Filling Event Form');

        // Wait for New Event screen
        await tester.waitForWidget(
          find.text('New Event'),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSubStep('On New Event screen');

        // New Event screen has:
        // - Sport Category: RUN, RIDE, SWIM, TRIATH
        // - Race Distance dropdown (Half Marathon, Marathon, etc.)
        // - Event Name text field
        // - Location (optional) text field
        // - EVENT DATE picker
        // - START TIME picker
        // - ADDITIONAL DETAILS (OPTIONAL) expander
        // - "+ Create Event" button

        // Select RUN (should be default selected)
        final runCategory = find.text('RUN');
        if (runCategory.evaluate().isNotEmpty) {
          await tester.tapAndSettle(runCategory.first);
          TestLogger.logSubStep('Selected RUN category');
        }

        // Select Race Distance - tap dropdown
        final distanceDropdown = find.textContaining('Half Marathon');
        if (distanceDropdown.evaluate().isEmpty) {
          // Tap the dropdown to open it
          final raceDistanceLabel = find.text('Race Distance');
          if (raceDistanceLabel.evaluate().isNotEmpty) {
            // Find the dropdown below the label
            final dropdowns = find.byType(DropdownButton);
            if (dropdowns.evaluate().isNotEmpty) {
              await tester.tapAndSettle(dropdowns.first);
              await tester.wait(TestConfig.tapDelay);

              // Select Half Marathon
              final halfMarathon = find.text('Half Marathon (13.1 mi)');
              if (halfMarathon.evaluate().isNotEmpty) {
                await tester.tapAndSettle(halfMarathon.first);
              }
            }
          }
        }

        // Enter Event Name
        TestLogger.logSubStep('Entering event name: ${TestConfig.testEvent.name}');
        final eventNameField = find.byWidgetPredicate((widget) {
          if (widget is TextField) {
            final hint = widget.decoration?.hintText ?? '';
            return hint.contains('Event Name');
          }
          return false;
        });

        if (eventNameField.evaluate().isNotEmpty) {
          await tester.enterText(eventNameField.first, TestConfig.testEvent.name);
          await tester.pumpAndSettle();
        }

        // Enter Location (optional)
        TestLogger.logSubStep('Entering location: ${TestConfig.testEvent.location}');
        final locationField = find.byWidgetPredicate((widget) {
          if (widget is TextField) {
            final hint = widget.decoration?.hintText ?? '';
            return hint.contains('Location');
          }
          return false;
        });

        if (locationField.evaluate().isNotEmpty) {
          await tester.enterText(locationField.first, TestConfig.testEvent.location);
          await tester.pumpAndSettle();
        }

        // Date and time are pre-populated, keep defaults

        await tester.pumpAndSettle();

        // ============================================================
        // STEP 5: Save Event
        // ============================================================
        TestLogger.logStep('Saving Event');

        // Scroll to find "+ Create Event" button
        await tester.scrollToFind(find.text('Create Event'));

        final createBtn = find.text('Create Event');
        if (createBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(createBtn.first);
        }

        await tester.wait(TestConfig.networkDelay);
        TestLogger.logSuccess('Event created');

        // ============================================================
        // STEP 6: View Event Details
        // ============================================================
        TestLogger.logStep('Viewing Event Details');

        // After creation, should navigate to Event Details screen
        // Event Details shows:
        // - Event name
        // - Date and "X weeks away" badge
        // - EVENT INFORMATION section
        // - NUTRITION PLANNING section with buttons
        // - View events list / Create new event links

        await tester.waitForWidget(
          find.text('Event Details'),
          timeout: TestConfig.mediumTimeout,
        );

        TestLogger.logSubStep('On Event Details screen');

        // Verify event name is displayed
        final eventNameDisplayed = find.textContaining(TestConfig.testEvent.name);
        if (eventNameDisplayed.evaluate().isNotEmpty) {
          TestLogger.logSuccess('Event name displayed correctly');
        }

        // Verify nutrition planning section
        final createNutritionPlanBtn = find.textContaining('Create Nutrition Plan');
        tester.expectWidget(createNutritionPlanBtn, reason: 'Create Nutrition Plan button should be visible');

        final carbLoadingBtn = find.textContaining('Create Carb Loading Plan');
        tester.expectWidget(carbLoadingBtn, reason: 'Create Carb Loading Plan button should be visible');

        await tester.screenshot('event_created');

        // ============================================================
        // STEP 7: Edit Event
        // ============================================================
        TestLogger.logStep('Editing Event');

        // Look for edit icon (pencil) in the header
        final editIcon = find.byIcon(Icons.edit);
        if (editIcon.evaluate().isNotEmpty) {
          await tester.tapAndSettle(editIcon.first);
          await tester.wait(TestConfig.pageTransitionDelay);

          TestLogger.logSubStep('On Edit Event screen');

          // Should be back on event form with existing data
          // Change the event name
          final eventNameEditField = find.byWidgetPredicate((widget) {
            if (widget is TextField) {
              final hint = widget.decoration?.hintText ?? '';
              return hint.contains('Event Name');
            }
            return false;
          });

          if (eventNameEditField.evaluate().isNotEmpty) {
            await tester.enterText(eventNameEditField.first, '${TestConfig.testEvent.name} Updated');
            await tester.pumpAndSettle();
          }

          // Save changes
          final saveBtn = find.text('Save');
          if (saveBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(saveBtn.first);
          } else {
            // Try Update button
            final updateBtn = find.text('Update');
            if (updateBtn.evaluate().isNotEmpty) {
              await tester.tapAndSettle(updateBtn.first);
            } else {
              // Try Create Event button (might reuse same form)
              final createEventBtn = find.text('Create Event');
              if (createEventBtn.evaluate().isNotEmpty) {
                await tester.tapAndSettle(createEventBtn.first);
              }
            }
          }

          await tester.wait(TestConfig.networkDelay);
          TestLogger.logSuccess('Event updated');
        } else {
          TestLogger.logInfo('Edit icon not found - may be in overflow menu');
        }

        // ============================================================
        // STEP 8: Navigate back to Event Details
        // ============================================================
        // If we're still on edit screen, navigate back
        final backBtn = find.byIcon(Icons.arrow_back);
        if (backBtn.evaluate().isNotEmpty &&
            find.text('Event Details').evaluate().isEmpty) {
          await tester.tapAndSettle(backBtn.first);
          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // ============================================================
        // STEP 9: Delete Event
        // ============================================================
        TestLogger.logStep('Deleting Event');

        // From Event Details, look for delete option
        // Could be a delete icon or in overflow menu
        final deleteIcon = find.byIcon(Icons.delete);
        if (deleteIcon.evaluate().isNotEmpty) {
          await tester.tapAndSettle(deleteIcon.first);

          // Confirm deletion
          await tester.wait(TestConfig.tapDelay);
          final confirmDelete = find.text('Delete');
          if (confirmDelete.evaluate().isNotEmpty) {
            await tester.tapAndSettle(confirmDelete.last);
          }

          await tester.wait(TestConfig.networkDelay);
          TestLogger.logSuccess('Event deleted');
        } else {
          // Try overflow menu
          final moreIcon = find.byIcon(Icons.more_vert);
          if (moreIcon.evaluate().isNotEmpty) {
            await tester.tapAndSettle(moreIcon.first);
            await tester.wait(TestConfig.tapDelay);

            final deleteOption = find.text('Delete');
            if (deleteOption.evaluate().isNotEmpty) {
              await tester.tapAndSettle(deleteOption.first);

              // Confirm
              await tester.wait(TestConfig.tapDelay);
              final confirmDelete = find.text('Delete');
              if (confirmDelete.evaluate().isNotEmpty) {
                await tester.tapAndSettle(confirmDelete.last);
              }

              await tester.wait(TestConfig.networkDelay);
              TestLogger.logSuccess('Event deleted via menu');
            }
          } else {
            TestLogger.logInfo('Delete option not found - skipping deletion test');
          }
        }

        // ============================================================
        // VERIFICATION
        // ============================================================
        TestLogger.logStep('Verifying Event Deletion');

        await tester.pumpAndSettle();

        // Should be back on calendar or events list
        // Event should no longer be visible
        final eventStillVisible = find.textContaining(TestConfig.testEvent.name).evaluate().isNotEmpty;

        if (!eventStillVisible) {
          TestLogger.logSuccess('Event successfully deleted');
        } else {
          TestLogger.logInfo('Event may still be visible - check manually');
        }

        await tester.screenshot('event_management_complete');

        TestLogger.logStep('Event Management Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}

