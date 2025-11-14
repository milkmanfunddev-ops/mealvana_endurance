import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';
import '../../../theme/kyle_design/theme_provider.dart';
// import '../../../theme/kyle_design/me_colors.dart';
// import '../../../theme/kyle_design/me_text_styles.dart';
// import '../../../theme/kyle_design/me_spacing.dart';

/// Theme toggle widget for Kyle's design system
/// Allows users to switch between light, dark, and system themes
class ThemeToggleWidget extends ConsumerWidget {
  const ThemeToggleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(kyleThemeModeProvider);
    final themeNotifier = ref.read(kyleThemeModeProvider.notifier);
    
    return themeModeAsync.when(
      data: (themeMode) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Appearance',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Theme selector card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                children: [
                  // Light theme option
                  _ThemeOption(
                    title: 'Light Mode',
                    subtitle: 'Clean cream background',
                    icon: FontAwesomeIcons.sun,
                    isSelected: themeMode == ThemeMode.light,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                  ),
                  
                  // Dark theme option
                  _ThemeOption(
                    title: 'Dark Mode',
                    subtitle: 'Rich blackberry background',
                    icon: FontAwesomeIcons.moon,
                    isSelected: themeMode == ThemeMode.dark,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                  ),
                  
                  // System theme option
                  _ThemeOption(
                    title: 'System',
                    subtitle: 'Follow device settings',
                    icon: FontAwesomeIcons.desktop,
                    isSelected: themeMode == ThemeMode.system,
                    onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Current theme indicator
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withOpacity(0.1),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(
                  color: AppColors.electrolyte,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FontAwesomeIcons.infoCircle,
                    color: AppColors.electrolyte,
                    size: AppIconSizes.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Dark mode is recommended for the best experience with Kyle\'s design system.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.electrolyte,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
        child: Text(
          'Error loading theme settings',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

/// Individual theme option widget
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: AppIconSizes.lg,
              height: AppIconSizes.lg,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.electrolyte 
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                borderRadius: AppRadius.circularRadius,
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? AppColors.textLight 
                    : Theme.of(context).colorScheme.onSurface,
                size: AppIconSizes.sm,
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(
                FontAwesomeIcons.checkCircle,
                color: AppColors.electrolyte,
                size: AppIconSizes.md,
              ),
          ],
        ),
      ),
    );
  }
}