import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../utils/responsive_breakpoints.dart';
import '../buttons/circular_action_button.dart';

/// Floating action buttons bar for bottom navigation
///
/// A pill-shaped container with circular action buttons:
/// - Calendar (left): Toggle calendar view
/// - Nutrition: Navigate to nutrition diary
/// - Coach (optional): Navigate to coach dashboard or my coaches
/// - Events: Navigate to events list
/// - Learn (right): Navigate to education/learn tab
///
/// The `activeButton` parameter indicates which button should be highlighted:
/// - 0: Calendar button (Activities screen)
/// - 1: Nutrition button (Nutrition Diary screen)
/// - 2: Coach button (Coach/My Coaches screen, if visible, web only)
/// - 2 or 3: Events button (Events screen)
/// - 3 or 4: Learn button (Education screen)
///
/// Example:
/// ```dart
/// FloatingActionButtonsBar(
///   activeButton: 0, // Calendar button active
///   onCalendarTap: () => toggleCalendarView(),
///   onCoachTap: () => navigateToCoach(),
///   onEventsTap: () => navigateToEvents(),
///   onLearnTap: () => navigateToLearn(),
/// )
/// ```
class FloatingActionButtonsBar extends StatelessWidget {
  const FloatingActionButtonsBar({
    super.key,
    required this.onCalendarTap,
    required this.onNutritionTap,
    required this.onCoachTap,
    required this.onEventsTap,
    required this.onLearnTap,
    required this.onPlusTap,
    this.activeButton,
    this.showCoachTab = false,
  });

  final VoidCallback onCalendarTap;
  final VoidCallback onNutritionTap;
  final VoidCallback onCoachTap;
  final VoidCallback onEventsTap;
  final VoidCallback onLearnTap;
  final VoidCallback onPlusTap;
  final int? activeButton;
  final bool showCoachTab;

  @override
  Widget build(BuildContext context) {
    // On wide screens the NavigationRail in TabsScreen replaces this widget.
    if (context.useNavigationRail) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveBackground = Colors.transparent;
    final activeBackground = isDark ? AppColors.cream : Colors.white;
    final frostedBackground = (isDark ? AppColors.blackberry : Colors.white)
        .withValues(alpha: 0.35);

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navigation pill container
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 43,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: frostedBackground,
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
                        key: const ValueKey('bottom_nav.calendar_tab'),
                        icon: FontAwesomeIcons.calendar.data,
                        onPressed: onCalendarTap,
                        semanticLabel: 'Calendar',
                        backgroundColor: activeButton == 0
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == 0
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                      const SizedBox(width: 8),
                      CircularActionButton(
                        key: const ValueKey('bottom_nav.diary_tab'),
                        icon: FontAwesomeIcons.utensils.data,
                        onPressed: onNutritionTap,
                        semanticLabel: 'Nutrition diary',
                        backgroundColor: activeButton == 1
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == 1
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                      const SizedBox(width: 8),
                      if (showCoachTab) ...[
                        CircularActionButton(
                          icon: FontAwesomeIcons.userTie.data,
                          onPressed: onCoachTap,
                          semanticLabel: 'Coach',
                          backgroundColor: activeButton == 2
                              ? activeBackground
                              : inactiveBackground,
                          iconColor: activeButton == 2
                              ? AppColors.blackberry
                              : (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CircularActionButton(
                        key: const ValueKey('bottom_nav.events_tab'),
                        icon: FontAwesomeIcons.calendarCheck.data,
                        onPressed: onEventsTap,
                        semanticLabel: 'Events',
                        backgroundColor: activeButton == (showCoachTab ? 3 : 2)
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == (showCoachTab ? 3 : 2)
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                      const SizedBox(width: 8),
                      CircularActionButton(
                        key: const ValueKey('bottom_nav.learn_tab'),
                        icon: FontAwesomeIcons.graduationCap.data,
                        onPressed: onLearnTap,
                        semanticLabel: 'Learn',
                        backgroundColor: activeButton == (showCoachTab ? 4 : 3)
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == (showCoachTab ? 4 : 3)
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Orange plus button
            Semantics(
              button: true,
              label: 'New activity',
              child: Tooltip(
                message: 'New activity',
                child: GestureDetector(
                  key: const ValueKey('calendar.create_activity_fab'),
                  onTap: onPlusTap,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppColors.cream,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
