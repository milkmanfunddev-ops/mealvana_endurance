import 'package:flutter/material.dart';

/// Horizontal bar showing intensity distribution with colored segments
///
/// Displays three segments proportional to the zone percentages:
/// - Green: Conversational (Z1-Z2)
/// - Yellow: Tempo (Z3-Z4)
/// - Red: All-Out (Z5+)
///
/// Props:
/// - conversationalPct: Percentage for Z1-Z2 (green segment)
/// - tempoPct: Percentage for Z3-Z4 (yellow segment)
/// - allOutPct: Percentage for Z5+ (red segment)
/// - enabled: Whether to show full opacity (true) or dimmed (false)
class IntensityCompositeBar extends StatelessWidget {
  const IntensityCompositeBar({
    super.key,
    required this.conversationalPct,
    required this.tempoPct,
    required this.allOutPct,
    this.height = 10.0,
    this.enabled = true,
  });

  final int conversationalPct;
  final int tempoPct;
  final int allOutPct;
  final double height;
  final bool enabled;

  // Zone colors based on design
  static const Color zoneConversationalColor = Color(0xFF4ADE80); // Green
  static const Color zoneTempoColor = Color(0xFFFBBF24); // Yellow/Orange
  static const Color zoneAllOutColor = Color(0xFFEF4444); // Red

  @override
  Widget build(BuildContext context) {
    // Validate that percentages sum to 100 (or close to it due to rounding)
    final total = conversationalPct + tempoPct + allOutPct;
    assert(
      total >= 99 && total <= 101,
      'Zone percentages must sum to 100 (got $total)',
    );

    // Calculate flex values (use at least 1 for zero percentages to avoid layout issues)
    final conversationalFlex = conversationalPct > 0 ? conversationalPct : 0;
    final tempoFlex = tempoPct > 0 ? tempoPct : 0;
    final allOutFlex = allOutPct > 0 ? allOutPct : 0;

    // Build semantic description of intensity distribution
    final semanticLabel = 'Intensity distribution: '
        '$conversationalPct% conversational, '
        '$tempoPct% tempo, '
        '$allOutPct% all-out';

    return Semantics(
      label: semanticLabel,
      readOnly: true,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2), // Fully rounded ends
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Row(
          children: [
            // Conversational zone (green)
            if (conversationalFlex > 0)
              Expanded(
                flex: conversationalFlex,
                child: Container(
                  color: enabled
                      ? zoneConversationalColor
                      : zoneConversationalColor.withValues(alpha: 0.4),
                ),
              ),

            // Tempo zone (yellow)
            if (tempoFlex > 0)
              Expanded(
                flex: tempoFlex,
                child: Container(
                  color: enabled ? zoneTempoColor : zoneTempoColor.withValues(alpha: 0.4),
                ),
              ),

            // All-Out zone (red)
            if (allOutFlex > 0)
              Expanded(
                flex: allOutFlex,
                child: Container(
                  color: enabled ? zoneAllOutColor : zoneAllOutColor.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
