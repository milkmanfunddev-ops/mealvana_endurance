import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Mealvana Pro screen showcasing upcoming premium features
class ProVersionScreen extends ConsumerWidget {
  const ProVersionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const ValueKey('pro_version.screen'),
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('pro_version.close_button'),
          icon: Icon(
            Icons.close,
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section
              Column(
                children: [
                  // Pro Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.orange, AppColors.dragonfruit],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.orange.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                    ),
                    child: Icon(
                      Icons.workspace_premium,
                      size: 48,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  Text(
                    key: const ValueKey('pro_version.title'),
                    'Mealvana Pro',
                    style: AppTextStyles.h1.copyWith(
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Coming Soon Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
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
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Subtitle
                  Text(
                    'Premium features are in development and will be available soon. Stay tuned for exciting updates!',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textDarkSecondary
                          : AppColors.textLightSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Features List
              Text(
                'Upcoming Features',
                style: AppTextStyles.h3.copyWith(
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Feature Cards
              _FeatureCard(
                icon: Icons.science,
                iconColor: AppColors.electrolyte,
                title: 'Advanced Analytics',
                description:
                    'Deep insights into your nutrition trends, performance metrics, and personalized recommendations.',
              ),
              const SizedBox(height: AppSpacing.md),

              _FeatureCard(
                icon: Icons.qr_code_scanner,
                iconColor: AppColors.orange,
                title: 'Barcode Scanning',
                description:
                    'Quickly add any food item by scanning its barcode with unlimited scans.',
              ),
              const SizedBox(height: AppSpacing.md),

              _FeatureCard(
                icon: Icons.restaurant_menu,
                iconColor: AppColors.dragonfruit,
                title: 'Custom Recipes',
                description:
                    'Create, save, and share your own custom food items and recipe combinations.',
              ),
              const SizedBox(height: AppSpacing.md),

              _FeatureCard(
                icon: Icons.sync,
                iconColor: AppColors.electrolyte,
                title: 'App Integrations',
                description:
                    'Sync with TrainingPeaks, Final Surge, V.O2, and other training platforms.',
              ),
              const SizedBox(height: AppSpacing.md),

              _FeatureCard(
                icon: Icons.support_agent,
                iconColor: AppColors.orange,
                title: 'Premium Support',
                description:
                    'Priority customer support with direct access to nutrition coaches.',
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Pricing Section
              BaseCard(
                key: const ValueKey('pro_version.pricing_card'),
                backgroundColor: isDark
                    ? AppColors.blackberryLight.withValues(alpha: 0.5)
                    : AppColors.surfaceLight,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 48,
                      color: isDark ? AppColors.inactive : AppColors.disabled,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Pricing Coming Soon',
                      style: AppTextStyles.h4.copyWith(
                        color: isDark
                            ? AppColors.textDark
                            : AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'We\'re finalizing the pricing details to ensure the best value for our athletes.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textLightSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Disabled Purchase Buttons
                    KylePrimaryButton(
                      text: 'Monthly Subscription',
                      onPressed: null, // Disabled
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    KylePrimaryButton(
                      text: 'Annual Subscription',
                      onPressed: null, // Disabled
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    KylePrimaryButton(
                      text: 'Lifetime Access',
                      onPressed: null, // Disabled
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Notify Me Section
              Text(
                'Want to be notified when Mealvana Pro launches?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              KylePrimaryButton(
                text: 'Get Notified',
                icon: Icons.notifications_active,
                onPressed: () {
                  // TODO: Implement notification signup
                  MealvanaSnackbar.showSuccess(
                    context,
                    'Notification system coming soon!',
                  );
                },
              ),

              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feature card widget
class _FeatureCard extends ConsumerWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h5.copyWith(
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textDarkSecondary
                        : AppColors.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
