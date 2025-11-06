import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Widget showing how many features are selected (e.g., "2 of 3 selected")
/// Changes color when 3 features are selected
class FeatureSelectionCounter extends StatelessWidget {
  const FeatureSelectionCounter({
    super.key,
    required this.selectedCount,
    this.requiredCount = 3,
  });

  final int selectedCount;
  final int requiredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isComplete = selectedCount == requiredCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isComplete
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete
              ? AppTheme.successColor
              : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
          width: isComplete ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Text indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.info_outline,
                color: isComplete
                    ? AppTheme.successColor
                    : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedCount of $requiredCount selected',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isComplete
                      ? AppTheme.successColor
                      : (isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: selectedCount / requiredCount,
              backgroundColor:
                  isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? AppTheme.successColor : AppTheme.successColor.withValues(alpha: 0.5),
              ),
              minHeight: 6,
            ),
          ),
          if (!isComplete) ...[
            const SizedBox(height: 8),
            Text(
              'Select ${requiredCount - selectedCount} more to continue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
