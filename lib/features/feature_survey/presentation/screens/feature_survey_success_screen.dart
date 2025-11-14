import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';

/// Success screen shown after submitting the survey
/// Displays the user's selected features and thank you message
class FeatureSurveySuccessScreen extends StatelessWidget {
  const FeatureSurveySuccessScreen({
    super.key,
    required this.selectedFeatures,
  });

  final List<Feature> selectedFeatures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
        title: Text(
          'Survey Complete',
          style: AppTextStyles.sectionTitle.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon with circular background
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
                    color: AppColors.blackberry,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Thank you message
              Text(
                'Thank You!',
                style: AppTextStyles.pageTitle.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your feedback gave us the boost we needed. Thank you!',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isDark
                      ? AppColors.textDarkSecondary
                      : AppColors.textLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              // Your top 3 picks
              Text(
                'Your Top 3 Picks:',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // List of selected features
              ...selectedFeatures.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return _FeatureItem(
                  rank: index + 1,
                  feature: feature,
                  isDark: isDark,
                );
              }),
              const Spacer(),
              // Done button
              KylePrimaryButton(
                text: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual feature item in the success list
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.rank,
    required this.feature,
    required this.isDark,
  });

  final int rank;
  final Feature feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15.0), // 15px from Kyle's design
        border: Border.all(
          color: AppColors.electrolyte.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank badge (circular with Electrolyte)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.electrolyte,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTextStyles.buttonPrimary.copyWith(
                  color: AppColors.blackberry,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Icon with circular background (36px per Kyle's design)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.electrolyte,
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              color: AppColors.blackberry,
              size: 18, // ~50% of container size
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Feature name
          Expanded(
            child: Text(
              feature.name,
              style: AppTextStyles.subtitle.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
