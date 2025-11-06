import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/app_theme.dart';

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
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thank you card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Success icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Thank you message
                  Text(
                    'Thank You!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your feedback gave us the boost we needed. Thank you!',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Your top 3 picks header
          Text(
            'Your Top 3 Picks:',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // List of selected features
          ...previousVotes.selectedFeatures.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            return _FeatureItem(
              rank: index + 1,
              feature: feature,
              isDarkMode: isDarkMode,
            );
          }),
          const SizedBox(height: 24),
          // Vote date
          Text(
            'Voted on ${_formatDate(previousVotes.votedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
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
    required this.isDarkMode,
  });

  final int rank;
  final Feature feature;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.successColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
      ),
    );
  }
}
