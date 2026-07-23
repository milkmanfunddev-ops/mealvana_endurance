import 'package:flutter/material.dart';

import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../domain/nutrient_transparency_data.dart';

/// Renders the always-visible TL;DR section for nutrient transparency.
///
/// Works for Carbs, Fluids, Sodium, and Protein — the accent color and
/// unit label are driven by [NutrientTransparencyData.nutrientColor] and
/// [NutrientTransparencyData.primaryUnit] rather than being hardcoded.
///
/// Follows the HTML artifact layout exactly:
///   1. Body paragraph (with **bold** support)
///   2. Formula block with left accent border + optional step numbers
///   3. Tip line with left accent border (pre-workout only)
///
/// Swim zero-state has its own distinct layout.
class NutrientTldrSection extends StatelessWidget {
  const NutrientTldrSection({super.key, required this.data});

  final NutrientTransparencyData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    final primaryText = isDark ? AppColors.textDark : AppColors.textLight;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    final accentColor = data.nutrientColor;

    if (data.isSwimZero) {
      return _buildSwimZeroState(
        context,
        primaryText,
        secondaryText,
        dimColor,
        accentColor,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body paragraph
        if (data.tldrBody != null) ...[
          _buildRichBody(data.tldrBody!, secondaryText, primaryText),
          const SizedBox(height: 12),
        ],

        // Formula block with left accent border
        if (data.tldrLines.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accentColor.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in data.tldrLines) ...[
                  if (line.showDividerBefore)
                    Padding(
                      padding: EdgeInsets.only(
                        top: 6,
                        bottom: 6,
                        left: line.stepNumber != null ? 20 : 0,
                      ),
                      child: Container(
                        height: 1,
                        color: accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                  _buildFormulaLine(
                    line,
                    primaryText,
                    secondaryText,
                    dimColor,
                    accentColor,
                  ),
                ],
              ],
            ),
          ),

        // Tip line
        if (data.tldrTip != null) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accentColor, width: 2)),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: _buildRichBody(
              data.tldrTip!,
              accentColor.withValues(alpha: 0.85),
              primaryText,
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSwimZeroState(
    BuildContext context,
    Color primaryText,
    Color secondaryText,
    Color dimColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body paragraph
        if (data.tldrBody != null) ...[
          _buildRichBody(data.tldrBody!, secondaryText, primaryText),
          const SizedBox(height: 12),
        ],
        // Swim zero block with left border
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: dimColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '0 ${data.primaryUnit}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: dimColor,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sport ceiling = 0 \u00b7 all steps skipped',
                style: TextStyle(fontSize: 12, color: dimColor, height: 1.5),
              ),
            ],
          ),
        ),
        if (data.swimCallout != null) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accentColor.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              data.swimCallout!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: accentColor.withValues(alpha: 0.85),
                height: 1.55,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormulaLine(
    FormulaLine line,
    Color primaryText,
    Color secondaryText,
    Color dimColor,
    Color accentColor,
  ) {
    final spans = line.segments.map((seg) {
      return TextSpan(
        text: seg.text,
        style: _segmentStyle(
          seg.style,
          primaryText,
          secondaryText,
          dimColor,
          accentColor,
        ),
      );
    }).toList();

    final richText = RichText(text: TextSpan(children: spans));

    if (line.stepNumber != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: 18,
              child: Text(
                line.stepNumber!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: dimColor,
                ),
              ),
            ),
            Expanded(child: richText),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: richText,
    );
  }

  TextStyle _segmentStyle(
    SegmentStyle style,
    Color primaryText,
    Color secondaryText,
    Color dimColor,
    Color accentColor,
  ) {
    switch (style) {
      case SegmentStyle.accent:
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: accentColor,
          height: 1.7,
        );
      case SegmentStyle.op:
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: dimColor,
          height: 1.7,
        );
      case SegmentStyle.dim:
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: secondaryText.withValues(alpha: 0.65),
          height: 1.7,
        );
      case SegmentStyle.result:
        return TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: primaryText,
          height: 1.7,
        );
    }
  }

  /// Parses **bold** markers and renders as RichText.
  Widget _buildRichBody(
    String text,
    Color normalColor,
    Color boldColor, {
    double fontSize = 13,
    double height = 1.7,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w600 : fontWeight,
            color: isBold ? boldColor : normalColor,
            height: height,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }
}
