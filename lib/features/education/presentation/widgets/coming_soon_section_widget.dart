import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Coming soon card matching ProVersionScreen's _FeatureCard pattern
class ComingSoonSectionWidget extends StatelessWidget {
  const ComingSoonSectionWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.notifyButtonKey,
  });

  final FaIconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Key? notifyButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FaIcon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),

              // Title + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h5.copyWith(
                        color: isDark
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Coming Soon badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.electrolyte,
                        borderRadius: AppRadius.buttonRadius,
                      ),
                      child: Text(
                        'Coming Soon',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KylePrimaryButton(
            key: notifyButtonKey,
            text: 'Notify Me',
            onPressed: null, // Disabled
          ),
        ],
      ),
    );
  }
}
