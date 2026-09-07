import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../utils/responsive_breakpoints.dart';
import '../buttons/circular_action_button.dart';

/// Floating bottom-navigation pill.
///
/// The Activities + Nutrition tabs are merged into a single **Fuel Timeline**
/// tab (the combined day/food/workout page), so the destinations are:
/// - Fuel Timeline (left, calendar icon) — index 0
/// - Food (optional, Pro-unlocked) — index 1
/// - Coach (optional, web only) — after Food when present
/// - Events / Learn (right)
///
/// The orange "new activity" FAB is gone — activities are created from the
/// "+ Add Activity" button on the Fuel Timeline itself.
class FloatingActionButtonsBar extends StatelessWidget {
  const FloatingActionButtonsBar({
    super.key,
    required this.onTimelineTap,
    required this.onCoachTap,
    required this.onEventsTap,
    required this.onLearnTap,
    this.onFoodTap,
    this.activeButton,
    this.showCoachTab = false,
    this.showFoodTab = false,
  });

  final VoidCallback onTimelineTap;
  final VoidCallback onCoachTap;
  final VoidCallback onEventsTap;
  final VoidCallback onLearnTap;

  /// Food tab (meal planning) — only when Pro is unlocked.
  final VoidCallback? onFoodTap;
  final int? activeButton;
  final bool showCoachTab;
  final bool showFoodTab;

  @override
  Widget build(BuildContext context) {
    // On wide screens the NavigationRail in TabsScreen replaces this widget.
    if (context.useNavigationRail) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const inactiveBackground = Colors.transparent;
    final activeBackground = isDark ? AppColors.cream : Colors.white;
    final frostedBackground = (isDark ? AppColors.blackberry : Colors.white)
        .withValues(alpha: 0.35);

    Color iconColor(bool active) => active
        ? AppColors.blackberry
        : (isDark ? AppColors.cream : AppColors.blackberry);
    Color bg(bool active) => active ? activeBackground : inactiveBackground;

    final foodTap = onFoodTap;
    final foodIndex = 1;
    final coachIndex = showFoodTab ? 2 : 1;
    final eventsIndex = (showCoachTab ? coachIndex + 1 : coachIndex);
    final learnIndex = eventsIndex + 1;

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
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
                    key: const ValueKey('bottom_nav.timeline_tab'),
                    icon: FontAwesomeIcons.calendar.data,
                    onPressed: onTimelineTap,
                    semanticLabel: 'Fuel Timeline',
                    backgroundColor: bg(activeButton == 0),
                    iconColor: iconColor(activeButton == 0),
                  ),
                  const SizedBox(width: 8),
                  if (showFoodTab && foodTap != null) ...[
                    CircularActionButton(
                      key: const ValueKey('bottom_nav.food_tab'),
                      icon: FontAwesomeIcons.bowlFood.data,
                      onPressed: foodTap,
                      semanticLabel: 'Food',
                      backgroundColor: bg(activeButton == foodIndex),
                      iconColor: iconColor(activeButton == foodIndex),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showCoachTab) ...[
                    CircularActionButton(
                      icon: FontAwesomeIcons.userTie.data,
                      onPressed: onCoachTap,
                      semanticLabel: 'Coach',
                      backgroundColor: bg(activeButton == coachIndex),
                      iconColor: iconColor(activeButton == coachIndex),
                    ),
                    const SizedBox(width: 8),
                  ],
                  CircularActionButton(
                    key: const ValueKey('bottom_nav.events_tab'),
                    icon: FontAwesomeIcons.calendarCheck.data,
                    onPressed: onEventsTap,
                    semanticLabel: 'Events',
                    backgroundColor: bg(activeButton == eventsIndex),
                    iconColor: iconColor(activeButton == eventsIndex),
                  ),
                  const SizedBox(width: 8),
                  CircularActionButton(
                    key: const ValueKey('bottom_nav.learn_tab'),
                    icon: FontAwesomeIcons.graduationCap.data,
                    onPressed: onLearnTap,
                    semanticLabel: 'Learn',
                    backgroundColor: bg(activeButton == learnIndex),
                    iconColor: iconColor(activeButton == learnIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
