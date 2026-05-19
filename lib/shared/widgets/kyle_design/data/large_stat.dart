import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Large stat display for Kyle's design system
/// Two-column layout with icon, label, and large value
class LargeStatDisplay extends ConsumerWidget {
  const LargeStatDisplay({
    super.key,
    required this.stats,
    this.backgroundColor,
    this.padding,
    this.firstStatKey,
    this.secondStatKey,
  });

  final List<StatItem> stats;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final Key? firstStatKey;
  final Key? secondStatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stats.length != 2) {
      throw ArgumentError('LargeStatDisplay requires exactly 2 stats');
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final statKey = index == 0 ? firstStatKey : secondStatKey;
          return _buildStatItem(context, stat, statKey);
        }).toList(),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, StatItem stat, [Key? itemKey]) {
    return Expanded(
      child: Column(
        key: itemKey,
        children: [
          // Icon
          Icon(
            stat.icon,
            size: AppIconSizes.xl,
            color:
                stat.iconColor ??
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Label
          Text(
            stat.label,
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Value
          Text(
            stat.value,
            style: AppTextStyles.dataNumberLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              //smaller font size for two-column layout
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single stat item for large display
class StatItem {
  const StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
}

/// Pace and burn stat display variant
class PaceBurnDisplay extends ConsumerWidget {
  const PaceBurnDisplay({
    super.key,
    required this.pace,
    required this.totalBurn,
    this.backgroundColor,
    this.paceStatKey,
    this.burnStatKey,
  });

  final String pace;
  final String totalBurn;
  final Color? backgroundColor;
  final Key? paceStatKey;
  final Key? burnStatKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LargeStatDisplay(
      stats: [
        StatItem(
          icon: FontAwesomeIcons.clock.data,
          label: 'PACE',
          value: pace,
          iconColor: Colors.orange,
        ),
        StatItem(
          icon: FontAwesomeIcons.fire.data,
          label: 'TOTAL BURN',
          value: totalBurn,
          iconColor: AppColors.dragonfruit,
        ),
      ],
      backgroundColor: backgroundColor,
      firstStatKey: paceStatKey,
      secondStatKey: burnStatKey,
    );
  }
}

/// Distance and time stat display variant
class DistanceTimeDisplay extends ConsumerWidget {
  const DistanceTimeDisplay({
    super.key,
    required this.distance,
    required this.duration,
    this.backgroundColor,
  });

  final String distance;
  final String duration;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LargeStatDisplay(
      stats: [
        StatItem(
          icon: FontAwesomeIcons.route.data,
          label: 'DISTANCE',
          value: distance,
          iconColor: AppColors.electrolyte,
        ),
        StatItem(
          icon: FontAwesomeIcons.clock.data,
          label: 'DURATION',
          value: duration,
          iconColor: AppColors.orange,
        ),
      ],
      backgroundColor: backgroundColor,
    );
  }
}

/// Single large stat widget
class SingleLargeStat extends ConsumerWidget {
  const SingleLargeStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.backgroundColor,
    this.iconColor,
    this.alignment = MainAxisAlignment.center,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? backgroundColor;
  final Color? iconColor;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: alignment == MainAxisAlignment.start
            ? MainAxisAlignment.start
            : alignment == MainAxisAlignment.end
            ? MainAxisAlignment.end
            : MainAxisAlignment.center,
        children: [
          // Icon
          Icon(
            icon,
            size: AppIconSizes.xl,
            color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Label
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Value
          Text(
            value,
            style: AppTextStyles.dataNumberLarge.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Compact stat display for smaller spaces
class CompactStatDisplay extends ConsumerWidget {
  const CompactStatDisplay({
    super.key,
    required this.stats,
    this.backgroundColor,
    this.padding,
  });

  final List<StatItem> stats;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: stats
            .map((stat) => _buildCompactStatItem(context, stat))
            .toList(),
      ),
    );
  }

  Widget _buildCompactStatItem(BuildContext context, StatItem stat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          // Icon
          Icon(
            stat.icon,
            size: AppIconSizes.controlIcon,
            color:
                stat.iconColor ??
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),

          const SizedBox(width: AppSpacing.sm),

          // Label
          Text(
            stat.label,
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Value
          Text(
            stat.value,
            style: AppTextStyles.dataNumber.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}
