import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/app_theme.dart';

/// Card widget for displaying a feature with checkbox
/// Tapping anywhere on the card toggles the checkbox
class FeatureCheckboxCard extends StatelessWidget {
  const FeatureCheckboxCard({
    super.key,
    required this.feature,
    required this.isSelected,
    required this.isEnabled,
    required this.onToggle,
  });

  final Feature feature;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppTheme.successColor
              : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isEnabled ? onToggle : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : (isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  feature.icon,
                  color: isSelected
                      ? AppTheme.successColor
                      : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isEnabled
                            ? null
                            : (isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isEnabled
                            ? (isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600)
                            : (isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Checkbox
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: isSelected,
                  onChanged: isEnabled ? (_) => onToggle() : null,
                  activeColor: AppTheme.successColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
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
