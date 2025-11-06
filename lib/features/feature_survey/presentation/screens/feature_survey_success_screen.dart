import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/app_theme.dart';

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
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: const Text('Survey Complete'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration,
                  color: AppTheme.successColor,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              // Thank you message
              Text(
                'Thank You!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your feedback gave us the boost we needed. Thank you!',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Your top 3 picks
              Text(
                'Your Top 3 Picks:',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // List of selected features
              ...selectedFeatures.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return _FeatureItem(
                  rank: index + 1,
                  feature: feature,
                  isDarkMode: isDarkMode,
                );
              }),
              const Spacer(),
              // Done button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
    required this.isDarkMode,
  });

  final int rank;
  final Feature feature;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              feature.icon,
              color: AppTheme.successColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Feature name
          Expanded(
            child: Text(
              feature.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
