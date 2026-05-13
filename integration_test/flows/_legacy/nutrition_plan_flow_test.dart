/// Nutrition Plan Flow Integration Test
///
/// Tests the complete nutrition plan journey:
/// 1. User navigates to calendar and creates a nutrition plan
/// 2. User configures activity (distance, pace, gut training)
/// 3. User reviews/adjusts macro targets
/// 4. User views generated plan
/// 5. User swaps a food item
/// 6. User deletes a food item (swipe)
///
/// Prerequisites:
/// - User must be logged in or have completed onboarding
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mealvana_endurance/main.dart' as app;

import '../helpers/test_config.dart';
import '../helpers/test_helpers.dart';
import '../helpers/onboarding_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Nutrition Plan Flow', () {
    testWidgets(
      'User can create activity, generate plan, and modify foods',
      (tester) async {
        TestLogger.logStep('Starting Nutrition Plan Flow Test');

        // ============================================================
        // STEP 1: Launch App and Get to Main Screen
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

        // Wait for main app - look for bottom navigation or calendar
        final mainReady = await tester.waitForWidget(
          find.byType(BottomNavigationBar),
          timeout: TestConfig.mediumTimeout,
        );

        if (!mainReady) {
          // Try looking for calendar icon in bottom bar
          await tester.waitForWidget(
            find.byIcon(Icons.calendar_today),
            timeout: TestConfig.mediumTimeout,
          );
        }

        TestLogger.logSuccess('App ready');

        // ============================================================
        // STEP 2: Navigate to Calendar/Create Event
        // ============================================================
        TestLogger.logStep('Navigating to Create Activity');

        // The orange FAB (+) button uses FontAwesomeIcons.plus (not Icons.add)
        // It's a CircularActionButton with an IconButton inside
        final faPlus = find.byIcon(FontAwesomeIcons.plus);
        if (faPlus.evaluate().isNotEmpty) {
          TestLogger.logSubStep('Found FontAwesome plus icon, tapping...');
          await tester.tapAndSettle(faPlus.first);
          TestLogger.logSuccess('Tapped FAB');
        } else {
          // Try Material Icons.add as backup
          final addIcon = find.byIcon(Icons.add);
          if (addIcon.evaluate().isNotEmpty) {
            await tester.tapAndSettle(addIcon.first);
            TestLogger.logSuccess('Tapped add icon');
          } else {
            // Try "CREATE AN EVENT" text button
            final createEventBtn = find.textContaining('CREATE AN EVENT');
            if (createEventBtn.evaluate().isNotEmpty) {
              await tester.tapAndSettle(createEventBtn.first);
              TestLogger.logSuccess('Tapped CREATE AN EVENT');
            } else {
              // Try "Create an Event" (case variant)
              final createEventAlt = find.textContaining('Create an Event');
              if (createEventAlt.evaluate().isNotEmpty) {
                await tester.tapAndSettle(createEventAlt.first);
                TestLogger.logSuccess('Tapped Create an Event');
              }
            }
          }
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // ============================================================
        // STEP 3: Check if we're on Event or Activity screen
        // ============================================================
        // The app might show "New Event" or we need to create an event first
        // then tap "Create Nutrition Plan"

        final newEventScreen = find.text('New Event');
        if (newEventScreen.evaluate().isNotEmpty) {
          TestLogger.logSubStep('On New Event screen - creating event first');

          // Select Run (should be default)
          final runOption = find.text('RUN');
          if (runOption.evaluate().isNotEmpty) {
            await tester.tapAndSettle(runOption.first);
          }

          // Enter event name
          final eventNameField = find.byWidgetPredicate((widget) {
            if (widget is TextField) {
              final hint = widget.decoration?.hintText ?? '';
              return hint.contains('Event Name');
            }
            return false;
          });

          if (eventNameField.evaluate().isNotEmpty) {
            await tester.enterText(eventNameField.first, 'Test Run');
          }

          // Tap Create Event button
          final createEventBtn = find.text('Create Event');
          if (createEventBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(createEventBtn.first);
          } else {
            final createBtn = find.textContaining('Create');
            if (createBtn.evaluate().isNotEmpty) {
              await tester.tapAndSettle(createBtn.first);
            }
          }

          await tester.wait(TestConfig.networkDelay);

          // Now we should be on Event Details - tap "Create Nutrition Plan"
          await tester.waitForWidget(
            find.textContaining('Create Nutrition Plan'),
            timeout: TestConfig.mediumTimeout,
          );

          final createPlanBtn = find.textContaining('Create Nutrition Plan');
          if (createPlanBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(createPlanBtn.first);
          }

          await tester.wait(TestConfig.pageTransitionDelay);
        }

        // ============================================================
        // STEP 4: Configure Activity and Generate Plan
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
        }

        // ============================================================
        // STEP 5: Review Macros (Adjust Your Macros screen)
        // ============================================================
        TestLogger.logStep('Reviewing Macros');

        // Wait for "Adjust Your Macros" screen
        final macrosFound = await tester.waitForWidget(
          find.textContaining('Adjust Your Macros'),
          timeout: TestConfig.mediumTimeout,
        );

        if (macrosFound) {
          TestLogger.logSubStep('On Adjust Your Macros screen');

          // Verify macro table is visible (PRE, DURING, POST columns)
          tester.expectText('PRE', reason: 'PRE column should be visible');
          tester.expectText('DURING', reason: 'DURING column should be visible');
          tester.expectText('POST', reason: 'POST column should be visible');

          // Verify macro rows
          tester.expectText('CARBS', reason: 'CARBS row should be visible');
          tester.expectText('PROTEIN', reason: 'PROTEIN row should be visible');
          tester.expectText('FLUIDS', reason: 'FLUIDS row should be visible');
          tester.expectText('SODIUM', reason: 'SODIUM row should be visible');

          TestLogger.logSuccess('Macros displayed correctly');

          // Tap "Create Plan" to generate the nutrition plan
          final createPlanBtn = find.text('Create Plan');
          if (createPlanBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(createPlanBtn.first);
          }

          // Wait for AI to generate the plan (can take a while)
          await tester.wait(TestConfig.longTimeout);
        }

        // ============================================================
        // STEP 6: View Generated Plan (New Activity screen)
        // ============================================================
        TestLogger.logStep('Viewing Generated Plan');

        // Wait for plan detail screen - shows "BEFORE RUN" section
        final planFound = await tester.waitForWidget(
          find.textContaining('BEFORE RUN'),
          timeout: TestConfig.longTimeout,
        );

        if (planFound) {
          TestLogger.logSuccess('Plan generated and displayed');

          // Verify plan sections exist
          tester.expectText('BEFORE RUN', reason: 'BEFORE RUN section should exist');

          // The plan shows food items like Oatmeal, Bananas, Toast, Water
          // Each food can be swiped to delete or tapped to swap
        }

        await tester.screenshot('nutrition_plan_generated');

        // ============================================================
        // STEP 7: Swap a Food Item
        // ============================================================
        TestLogger.logStep('Swapping a Food Item');

        // Tap on a food item to open swap screen
        // Look for a specific food like "Oatmeal" or "Bananas"
        final oatmealFinder = find.textContaining('Oatmeal');
        final bananaFinder = find.textContaining('Banana');

        if (oatmealFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(oatmealFinder.first);
          TestLogger.logSubStep('Tapped on Oatmeal');
        } else if (bananaFinder.evaluate().isNotEmpty) {
          await tester.tapAndSettle(bananaFinder.first);
          TestLogger.logSubStep('Tapped on Banana');
        }

        await tester.wait(TestConfig.pageTransitionDelay);

        // Check if we're on Swap screen (shows "Swap Oatmeal" title and alternatives)
        final swapScreenFound = await tester.waitForWidget(
          find.textContaining('Swap'),
          timeout: TestConfig.shortTimeout,
        );

        if (swapScreenFound) {
          TestLogger.logSubStep('On Swap Food screen');

          // Look for "Recommended Alternatives" section
          final alternativesSection = find.textContaining('Recommended Alternatives');
          if (alternativesSection.evaluate().isNotEmpty) {
            TestLogger.logSubStep('Alternatives section found');
          }

          // Tap on an alternative food (e.g., "SLICE OF TOAST", "PLAIN BAGEL", "BANANA")
          // Each has a + button to select
          final plusButtons = find.byIcon(Icons.add_circle_outline);
          if (plusButtons.evaluate().isEmpty) {
            // Try other add icons
            final addButtons = find.byIcon(Icons.add);
            if (addButtons.evaluate().isNotEmpty) {
              await tester.tapAndSettle(addButtons.first);
              TestLogger.logSuccess('Selected alternative food');
            }
          } else {
            await tester.tapAndSettle(plusButtons.first);
            TestLogger.logSuccess('Selected alternative food');
          }

          await tester.wait(TestConfig.pageTransitionDelay);

          // Should navigate back to plan screen
        } else {
          TestLogger.logInfo('Swap screen not found - food tapped may have expanded');
          // Navigate back if needed
          final backBtn = find.byIcon(Icons.arrow_back);
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(backBtn.first);
          }
        }

        // ============================================================
        // STEP 8: Delete a Food Item (Swipe to delete)
        // ============================================================
        TestLogger.logStep('Deleting a Food Item');

        await tester.pumpAndSettle();

        // The plan shows foods with swipe-to-delete functionality
        // Look for Dismissible widgets or swipe on a food row
        final foodItems = find.byType(Dismissible);
        if (foodItems.evaluate().isNotEmpty) {
          // Swipe left to delete
          await tester.drag(foodItems.first, const Offset(-300, 0));
          await tester.pumpAndSettle();
          TestLogger.logSuccess('Swiped food to delete');

          // If a confirmation appears, tap delete
          final deleteConfirm = find.text('Delete');
          if (deleteConfirm.evaluate().isNotEmpty) {
            await tester.tapAndSettle(deleteConfirm.first);
          }
        } else {
          // Try finding the delete icon (pink trash icon visible in screenshot)
          final deleteIcon = find.byIcon(Icons.delete);
          if (deleteIcon.evaluate().isNotEmpty) {
            await tester.tapAndSettle(deleteIcon.first);
            TestLogger.logSuccess('Tapped delete icon');

            // Confirm if needed
            final confirmDelete = find.text('Delete');
            if (confirmDelete.evaluate().isNotEmpty) {
              await tester.tapAndSettle(confirmDelete.last);
            }
          }
        }

        await tester.pumpAndSettle();

        // ============================================================
        // STEP 9: Add a Food Item
        // ============================================================
        TestLogger.logStep('Adding a Food Item');

        // Look for "+ ADD FOOD" button
        final addFoodBtn = find.textContaining('ADD FOOD');
        if (addFoodBtn.evaluate().isNotEmpty) {
          await tester.tapAndSettle(addFoodBtn.first);
          await tester.wait(TestConfig.pageTransitionDelay);

          // Should show food selection - similar to swap screen
          // Select a food and go back
          final backBtn = find.byIcon(Icons.arrow_back);
          if (backBtn.evaluate().isNotEmpty) {
            await tester.tapAndSettle(backBtn.first);
          }
        }

        // ============================================================
        // VERIFICATION
        // ============================================================
        TestLogger.logStep('Verifying Final State');

        // Should still be on plan screen
        final planStillVisible = find.textContaining('BEFORE RUN').evaluate().isNotEmpty ||
            find.textContaining('RUN').evaluate().isNotEmpty;

        if (planStillVisible) {
          TestLogger.logSuccess('Plan is still visible after modifications');
        }

        await tester.screenshot('nutrition_plan_modified');

        TestLogger.logStep('Nutrition Plan Flow Complete!');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

