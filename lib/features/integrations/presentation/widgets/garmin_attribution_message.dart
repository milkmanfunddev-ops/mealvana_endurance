import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import 'garmin_attribution.dart';

/// Garmin "this data came from Garmin" disclosure.
///
/// Renders the [GarminAttribution] chip plus a short sentence explaining
/// which data on the surrounding surface is Garmin-sourced. Designed to be
/// dropped beneath any UI surface that displays Garmin-derived data —
/// weight from a connected scale, body fat from Index, activity calories
/// from a watch upload, etc. — fulfilling the Garmin Developer API Brand
/// Guidelines requirement that Garmin-derived data be attributed wherever
/// it surfaces.
///
/// Use [subject] to substitute a domain-specific noun ("Weight", "Body fat
/// %", "Workout calories"); the default reads "This data".
class GarminAttributionMessage extends StatelessWidget {
  const GarminAttributionMessage({
    super.key,
    this.deviceName,
    this.subject = 'This data',
    this.compact = false,
  });

  /// Optional device model surfaced from the activity push payload
  /// (`garmin_device_name`). When null/empty, falls back to "Garmin Connect".
  final String? deviceName;

  /// Sentence subject. Examples: "Weight", "Body fat %", "Activity calories".
  /// Defaults to "This data" for generic surfaces.
  final String subject;

  /// Compact mode renders inline (no card padding) for use inside dense
  /// rows; standard mode adds vertical padding so it reads as a footer.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final attributionTarget = _attributionTarget(deviceName);
    final padding = compact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GarminAttribution(
            deviceName: deviceName,
            style: GarminAttributionStyle.compact,
          ),
          const SizedBox(height: 4),
          Text(
            '$subject is pulled from your $attributionTarget account.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  static String _attributionTarget(String? deviceName) {
    final trimmed = deviceName?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Garmin Connect';
    final lower = trimmed.toLowerCase();
    if (lower == 'unknown' || lower == 'garmin') return 'Garmin Connect';
    if (lower.startsWith('garmin')) return trimmed;
    return 'Garmin $trimmed';
  }
}
