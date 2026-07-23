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
/// - Coach (optional, web only) — index 1
/// - Events — index 1 (mobile) / 2 (web)
/// - Learn (right) — index 2 (mobile) / 3 (web)
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
    this.activeButton,
    this.showCoachTab = false,
  });

  final VoidCallback onTimelineTap;
  final VoidCallback onCoachTap;
  final VoidCallback onEventsTap;
  final VoidCallback onLearnTap;
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
    const inactiveBackground = Colors.transparent;
    final activeBackground = isDark ? AppColors.cream : Colors.white;
    final frostedBackground = (isDark ? AppColors.blackberry : Colors.white)
        .withValues(alpha: 0.35);

    Color iconColor(bool active) => active
        ? AppColors.blackberry
        : (isDark ? AppColors.cream : AppColors.blackberry);
    Color bg(bool active) => active ? activeBackground : inactiveBackground;

    final eventsIndex = showCoachTab ? 2 : 1;
    final learnIndex = showCoachTab ? 3 : 2;

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
                  if (showCoachTab) ...[
                    CircularActionButton(
                      icon: FontAwesomeIcons.userTie.data,
                      onPressed: onCoachTap,
                      semanticLabel: 'Coach',
                      backgroundColor: bg(activeButton == 1),
                      iconColor: iconColor(activeButton == 1),
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
