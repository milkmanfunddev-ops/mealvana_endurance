import 'package:flutter/material.dart';

import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../integrations/presentation/widgets/garmin_attribution.dart';

/// Displays coach notes / provider description for an activity.
/// Only shown when the activity has notes and was synced from a provider.
class ActivityCoachNotesWidget extends StatelessWidget {
  final Activity activity;

  const ActivityCoachNotesWidget({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final notes = activity.notes;
    if (notes == null || notes.trim().isEmpty) return const SizedBox.shrink();

    final isFromTP = activity.syncedFromProvider == 'training_peaks';
    final isFromFS = activity.syncedFromProvider == 'final_surge';
    final isFromGarmin = activity.syncedFromProvider == 'garmin';
    final isFromVdot = activity.syncedFromProvider == 'vdot';
    final providerName = isFromTP
        ? 'TrainingPeaks'
        : isFromFS
            ? 'Final Surge'
            : isFromVdot
                ? 'V.O2'
                : null;

    // Extract the coach description (before metadata line)
    // The notes format from TP transformer: "description\nElevation: ... | Calories: ... | Tags: ..."
    final coachDescription = _extractDescription(notes);
    if (coachDescription.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, size: 16, color: AppColors.electrolyte),
              const SizedBox(width: 6),
              Text(
                isFromGarmin
                    ? 'Coach Notes (from'
                    : providerName != null
                        ? 'Coach Notes (from $providerName)'
                        : 'Notes',
                style: const TextStyle(
                  color: AppColors.electrolyte,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isFromGarmin) ...[
                const SizedBox(width: 4),
                GarminAttribution(deviceName: activity.garminDeviceName),
                const Text(
                  ')',
                  style: TextStyle(
                    color: AppColors.electrolyte,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coachDescription,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Extract the description portion from notes (before metadata).
  /// Metadata lines contain patterns like "Elevation:" or "Tags:" with pipe separators.
  String _extractDescription(String notes) {
    final lines = notes.split('\n');
    final descriptionLines = <String>[];

    for (final line in lines) {
      // Stop at metadata lines (contain pipe-separated values with known prefixes)
      if (_isMetadataLine(line)) break;
      // Skip Mealvana writeback blocks
      if (line.contains('[Mealvana')) break;
      descriptionLines.add(line);
    }

    return descriptionLines.join('\n').trim();
  }

  bool _isMetadataLine(String line) {
    final trimmed = line.trim();
    return (trimmed.contains('Elevation:') ||
            trimmed.contains('Calories:') ||
            trimmed.contains('Tags:')) &&
        trimmed.contains('|');
  }
}
