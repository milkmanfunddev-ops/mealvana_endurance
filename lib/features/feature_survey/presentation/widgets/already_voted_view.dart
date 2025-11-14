import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';

/// Widget showing the user has already voted
/// Displays their previous selections in a read-only format
class AlreadyVotedView extends StatelessWidget {
  const AlreadyVotedView({
    super.key,
    required this.previousVotes,
  });

  final FeatureSurveyResponse previousVotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thank you card
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(15.0), // 15px from Kyle's design
              border: Border.all(
                color: AppColors.electrolyte.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Success icon with circular background
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.blackberry,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Thank you message
                Text(
                  'Thank You!',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your feedback gave us the boost we needed. Thank you!',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark
                        ? AppColors.textDarkSecondary
                        : AppColors.textLightSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Your top 3 picks header
          Text(
            'Your Top 3 Picks:',
            style: AppTextStyles.sectionTitle.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // List of selected features
          ...previousVotes.selectedFeatures.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return _FeatureItem(
              rank: index + 1,
              feature: feature,
              isDark: isDark,
            );
          }),
          const SizedBox(height: AppSpacing.xl),
          // Vote date
          Text(
            'Voted on ${_formatDate(previousVotes.votedAt)}',
            style: AppTextStyles.smallLabel.copyWith(
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textLightSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Individual feature item in the "already voted" list
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
