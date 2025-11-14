import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../buttons/circular_action_button.dart';

/// Floating action buttons bar for bottom navigation
///
/// A pill-shaped container with four circular action buttons:
/// - Calendar (left): Toggle calendar view
/// - Survey (center-left): Navigate to feature survey
/// - Menu (center-right): Navigate to settings
/// - Plus (right): Create new activity
///
/// Replaces the traditional bottom navigation bar with a more compact,
/// modern floating design matching Kyle's UI specifications.
///
/// The `activeButton` parameter indicates which button should be highlighted:
/// - 0: Calendar button (Activities screen)
/// - 1: Survey button (Feature Survey screen)
/// - 2: Menu button (Settings screen)
///
/// Example:
/// ```dart
/// FloatingActionButtonsBar(
///   activeButton: 0, // Calendar button active
///   onCalendarTap: () => toggleCalendarView(),
///   onSurveyTap: () => navigateToSurvey(),
///   onMenuTap: () => navigateToSettings(),
///   onAddTap: () => createNewActivity(),
/// )
/// ```
class FloatingActionButtonsBar extends StatelessWidget {
  const FloatingActionButtonsBar({
    super.key,
    required this.onCalendarTap,
    required this.onSurveyTap,
    required this.onMenuTap,
    required this.onAddTap,
    this.activeButton,
  });

  final VoidCallback onCalendarTap;
  final VoidCallback onSurveyTap;
  final VoidCallback onMenuTap;
  final VoidCallback onAddTap;
  final int? activeButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveBackground = Colors.transparent;
    final activeBackground = isDark ? AppColors.cream : Colors.white;

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill container with calendar, survey, and menu buttons
            Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularActionButton(
                    icon: FontAwesomeIcons.calendar,
                    onPressed: onCalendarTap,
                    backgroundColor: activeButton == 0
                        ? activeBackground
                        : inactiveBackground,
                    iconColor: activeButton == 0
                        ? AppColors.blackberry
                        : (isDark ? AppColors.cream : AppColors.blackberry),
                  ),
                  const SizedBox(width: 8),
                  CircularActionButton(
                    icon: FontAwesomeIcons.clipboardList,
                    onPressed: onSurveyTap,
                    backgroundColor: activeButton == 1
                        ? activeBackground
                        : inactiveBackground,
                    iconColor: activeButton == 1
                        ? AppColors.blackberry
                        : (isDark ? AppColors.cream : AppColors.blackberry),
                  ),
                  const SizedBox(width: 8),
                  CircularActionButton(
                    icon: FontAwesomeIcons.ellipsis,
                    onPressed: onMenuTap,
                    backgroundColor: activeButton == 2
                        ? activeBackground
                        : inactiveBackground,
                    iconColor: activeButton == 2
                        ? AppColors.blackberry
                        : (isDark ? AppColors.cream : AppColors.blackberry),
                  ),
                ],
              ),
            ),
            // Spacing between pill and plus button
            const SizedBox(width: 12),
            // Plus button outside the pill
            CircularActionButton(
              icon: FontAwesomeIcons.plus,
              onPressed: onAddTap,
              backgroundColor: AppColors.orange,
              iconColor: AppColors.cream,
            ),
          ],
        ),
      ),
    );
  }
}
