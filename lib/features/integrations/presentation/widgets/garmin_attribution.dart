import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Attribution chip rendered anywhere the UI surfaces data that originated
/// from a Garmin Connect activity upload.
///
/// Usage is dictated by Garmin's Developer API Brand Guidelines:
///   * Attribution is required on primary *and* secondary screens where
///     Garmin-derived data is displayed.
///   * Preferred form is `[tag logo] Garmin [device model]` (e.g.
///     "Garmin Forerunner 955"). When no device model is known we fall
///     back to `Garmin Connect` — never a bare "Garmin" token.
///   * The Garmin name must be written in full ("Garmin"/"Garmin Connect")
///     and never abbreviated.
class GarminAttribution extends StatelessWidget {
  const GarminAttribution({
    super.key,
    this.deviceName,
    this.style = GarminAttributionStyle.compact,
  });

  /// Device model surfaced from the activity push payload
  /// (`garmin_device_name`). When null or empty, falls back to
  /// "Garmin Connect".
  final String? deviceName;

  final GarminAttributionStyle style;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.cream : AppColors.blackberry;

    final attributionText = _buildAttributionText(deviceName);
    final (double logoHeight, double fontSize) = switch (style) {
      GarminAttributionStyle.compact => (10, 10),
      GarminAttributionStyle.standard => (14, 12),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          isDark
              ? 'assets/images/integrations/garmin_tag_white.png'
              : 'assets/images/integrations/garmin_tag_black.png',
          height: logoHeight,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            attributionText,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: baseColor.withValues(alpha: 0.7),
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _buildAttributionText(String? deviceName) {
    final trimmed = deviceName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Garmin Connect';
    }
    final lower = trimmed.toLowerCase();
    // Garmin sends "unknown" when the device model isn't identified.
    // Bare "Garmin" alone also violates brand guidelines.
    // In both cases, fall back to the full brand name.
    if (lower == 'unknown' || lower == 'garmin') {
      return 'Garmin Connect';
    }
    if (lower.startsWith('garmin')) {
      return trimmed;
    }
    return 'Garmin $trimmed';
  }
}

enum GarminAttributionStyle {
  /// Small footprint — for list cards and dense rows.
  compact,

  /// Larger — for detail screens and footer contexts.
  standard,
}
