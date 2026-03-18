import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../buttons/circular_action_button.dart';

/// Floating action buttons bar for bottom navigation
///
/// A pill-shaped container with circular action buttons:
/// - Calendar (left): Toggle calendar view
/// - Coach (optional): Navigate to coach dashboard or my coaches
/// - Events: Navigate to events list
/// - Learn: Navigate to education/learn tab
/// - Menu (right): Navigate to settings
///
/// The `activeButton` parameter indicates which button should be highlighted:
/// - 0: Calendar button (Activities screen)
/// - 1: Coach button (Coach/My Coaches screen, if visible)
/// - 1 or 2: Events button (Events screen)
/// - 2 or 3: Learn button (Education screen)
/// - 3 or 4: Menu button (Settings screen)
///
/// Example:
/// ```dart
/// FloatingActionButtonsBar(
///   activeButton: 0, // Calendar button active
///   onCalendarTap: () => toggleCalendarView(),
///   onCoachTap: () => navigateToCoach(),
///   onEventsTap: () => navigateToEvents(),
///   onMenuTap: () => navigateToSettings(),
/// )
/// ```
class FloatingActionButtonsBar extends StatelessWidget {
  const FloatingActionButtonsBar({
    super.key,
    required this.onCalendarTap,
    required this.onCoachTap,
    required this.onEventsTap,
    required this.onLearnTap,
    required this.onMenuTap,
    required this.onPlusTap,
    this.activeButton,
    this.showCoachTab = false,
  });

  final VoidCallback onCalendarTap;
  final VoidCallback onCoachTap;
  final VoidCallback onEventsTap;
  final VoidCallback onLearnTap;
  final VoidCallback onMenuTap;
  final VoidCallback onPlusTap;
  final int? activeButton;
  final bool showCoachTab;

  @override
  Widget build(BuildContext context) {
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
                      if (showCoachTab) ...[
                        CircularActionButton(
                          icon: FontAwesomeIcons.userTie,
                          onPressed: onCoachTap,
                          backgroundColor: activeButton == 1
                              ? activeBackground
                              : inactiveBackground,
                          iconColor: activeButton == 1
                              ? AppColors.blackberry
                              : (isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry),
                        ),
                        const SizedBox(width: 8),
                      ],
                      CircularActionButton(
                        icon: FontAwesomeIcons.calendarCheck,
                        onPressed: onEventsTap,
                        backgroundColor: activeButton == (showCoachTab ? 2 : 1)
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == (showCoachTab ? 2 : 1)
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                      const SizedBox(width: 8),
                      CircularActionButton(
                        icon: FontAwesomeIcons.graduationCap,
                        onPressed: onLearnTap,
                        backgroundColor: activeButton == (showCoachTab ? 3 : 2)
                            ? activeBackground
                            : inactiveBackground,
                        iconColor: activeButton == (showCoachTab ? 3 : 2)
                            ? AppColors.blackberry
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                      ),
                      const SizedBox(width: 8),
                      CircularActionButton(
                        icon: FontAwesomeIcons.ellipsis,
                        onPressed: onMenuTap,
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
            GestureDetector(
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
                child: const Icon(Icons.add, color: AppColors.cream, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
