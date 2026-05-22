import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../providers/new_activity_coordinator.dart';

/// Sport Selector - Four icon buttons for selecting sport type
///
/// Matches Kyle's design: RUNNING | BIKING | SWIMMING | BRICK
/// Selected sport has dark background, unselected are outlined
class SportSelector extends ConsumerWidget {
  const SportSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinatorState = ref.watch(newActivityCoordinatorProvider);
    final coordinator = ref.read(newActivityCoordinatorProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            _SportButton(
              key: const ValueKey('activity_create.tab_running'),
              icon: FontAwesomeIcons.personRunning.data,
              label: 'RUNNING',
              isSelected: coordinatorState.selectedTab == SportTab.running,
              onTap: () => coordinator.selectTab(SportTab.running),
              isDark: isDark,
            ),
            const SizedBox(width: AppSpacing.sm),
            _SportButton(
              key: const ValueKey('activity_create.tab_biking'),
              icon: FontAwesomeIcons.personBiking.data,
              label: 'BIKING',
              isSelected: coordinatorState.selectedTab == SportTab.cycling,
              onTap: () => coordinator.selectTab(SportTab.cycling),
              isDark: isDark,
            ),
            const SizedBox(width: AppSpacing.sm),
            _SportButton(
              key: const ValueKey('activity_create.tab_swimming'),
              icon: FontAwesomeIcons.personSwimming.data,
              label: 'SWIMMING',
              isSelected: coordinatorState.selectedTab == SportTab.swimming,
              onTap: () => coordinator.selectTab(SportTab.swimming),
              isDark: isDark,
            ),
            const SizedBox(width: AppSpacing.sm),
            _SportButton(
              key: const ValueKey('activity_create.tab_brick'),
              icon: FontAwesomeIcons.link.data,
              label: 'BRICK',
              isSelected: coordinatorState.selectedTab == SportTab.brick,
              onTap: () => coordinator.selectTab(SportTab.brick),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _SportButton extends StatelessWidget {
  const _SportButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cream : AppColors.blackberry)
              : Colors.transparent,
          border: Border.all(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? (isDark ? AppColors.blackberry : AppColors.cream)
                  : (isDark
                        ? AppColors.cream.withValues(alpha: 0.5)
                        : AppColors.blackberry.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.smallLabel.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? (isDark ? AppColors.blackberry : AppColors.cream)
                    : (isDark
                          ? AppColors.cream.withValues(alpha: 0.5)
                          : AppColors.blackberry.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
