import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import '../icons/activity_icon.dart';
import '../buttons/primary_button.dart';
import '../buttons/tertiary_button.dart';

/// Extension to convert ActivityType to KyleActivityType
extension ActivityTypeToKyle on ActivityType {
  KyleActivityType toKyleActivityType() {
    switch (this) {
      case ActivityType.running:
        return KyleActivityType.running;
      case ActivityType.cycling:
        return KyleActivityType.cycling;
      case ActivityType.swimming:
        return KyleActivityType.swimming;
      case ActivityType.triathlon:
        return KyleActivityType.triathlon;
      case ActivityType.duathlon:
        return KyleActivityType.other;
      case ActivityType.multisport:
        return KyleActivityType.other;
      case ActivityType.brick:
        return KyleActivityType.triathlon; // Map brick to triathlon for now
    }
  }
}

/// Activity hero card for Kyle's design system
/// Large card with activity icon, title, and details
class ActivityHeroCard extends ConsumerWidget {
  const ActivityHeroCard({
    super.key,
    required this.activityType,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.backgroundColor,
    this.showActionButton = false,
    this.actionButtonText,
    this.onActionButtonPressed,
  });

  final ActivityType activityType;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool showActionButton;
  final String? actionButtonText;
  final VoidCallback? onActionButtonPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                // Activity icon and title
                Row(
                  children: [
                    KyleActivityIcon(
                      activityType: activityType.toKyleActivityType(),
                      size: AppIconSizes.activityIcon,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.subtitle.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Action button
                if (showActionButton && actionButtonText != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: KylePrimaryButton(
                      text: actionButtonText!,
                      onPressed: onActionButtonPressed ?? () {},
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's activity card variant
class TodaysActivityCard extends ConsumerWidget {
  const TodaysActivityCard({
    super.key,
    required this.activityType,
    required this.title,
    required this.subtitle,
    this.onComplete,
    this.onSkip,
    this.isCompleted = false,
  });

  final ActivityType activityType;
  final String title;
  final String subtitle;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: isCompleted 
                  ? AppColors.electrolyte.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // Header with icon and title
              Row(
                children: [
                  KyleActivityIcon(
                    activityType: activityType.toKyleActivityType(),
                    size: AppIconSizes.activityIcon,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.subtitle.copyWith(
                            color: isCompleted
                                ? AppColors.electrolyte
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Icon(
                      FontAwesomeIcons.circleCheck,
                      color: AppColors.electrolyte,
                      size: AppIconSizes.controlIcon,
                    ),
                ],
              ),
              
              // Action buttons
              if (!isCompleted) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: KylePrimaryButton(
                        text: 'Complete',
                        onPressed: onComplete,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    KyleTertiaryButton(
                      text: 'Skip',
                      onPressed: onSkip,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Upcoming event card variant
class UpcomingEventCard extends ConsumerWidget {
  const UpcomingEventCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dateText,
    required this.daysAway,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String dateText;
  final String daysAway;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Event icon
                Container(
                  width: AppIconSizes.activityIcon,
                  height: AppIconSizes.activityIcon,
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.calendar,
                    size: AppIconSizes.activityIcon * 0.5,
                    color: AppColors.electrolyte,
                  ),
                ),

                const SizedBox(width: AppSpacing.md),

                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.subtitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Date badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withValues(alpha: 0.1),
                    borderRadius: AppRadius.inputRadius,
                  ),
                  child: Column(
                    children: [
                      Text(
                        dateText,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.electrolyte,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        daysAway,
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.electrolyte,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}