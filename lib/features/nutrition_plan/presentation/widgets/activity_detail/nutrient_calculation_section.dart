import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../domain/nutrient_transparency_data.dart';
import 'transparency_accordion.dart';

/// Renders the "Calculation" accordion — the step-numbered breakdown
/// that shows how the effective sweat rate, replacement %, floor, and
/// ceiling combine to produce the final recommendation.
///
/// Matches the Notion/Figma screenshots:
///
///   Calculation ⌄
///     CALCULATE EFFECTIVE SWEAT RATE
///       ① medium sweater → 1.28 L/hr (50th pct)
///       ② 22°C → × 1.0 = 1.28 L/hr
///       ③ 55% humidity → × 1.01 = 1.29 L/hr
///       ④ outdoor → × 1.0 = 1.29 L/hr effective
///     ─────
///     REPLACEMENT STRATEGY
///       ⑤ 90 min → 50% → 1.29 × 1000 × 0.50 = 645 ml/hr
///       ↓ floor = (1935 - 1300) ÷ 1.5 = 423 ml/hr (2% of 65 kg)
///       ↑ ceiling = min(800, 1290) = 800 ml/hr (running GI limit)
///       ✓ 645 ml/hr × 1.5 hr = 968 ml (33 oz)
///   (optional amber warning box)
class NutrientCalculationSection extends ConsumerWidget {
  const NutrientCalculationSection({super.key, required this.data});

  final NutrientTransparencyData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.calculationSections.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textDark : AppColors.textLight;
    final secondaryText =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    final accentColor = data.nutrientColor;

    return TransparencyAccordion(
      title: 'Calculation',
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: accentColor.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < data.calculationSections.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    height: 1,
                    color: accentColor.withValues(alpha: 0.22),
                  ),
                ),
              _buildSection(
                data.calculationSections[i],
                primaryText,
                secondaryText,
                dimColor,
                accentColor,
              ),
            ],
            if (data.calculationWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: Text(
                  data.calculationWarning!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.orange,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            // "Does this make sense?" feedback footer — fires Mixpanel.
            const SizedBox(height: 14),
            _CalcFeedbackFooter(
              nutrient: data.nutrientLabel,
              phase: data.phase,
              onVote: (vote) {
                ref.read(analyticsTrackerProvider).track(
                  'transparency_calc_feedback',
                  properties: {
                    'nutrient': data.nutrientLabel,
                    'phase': data.phase,
                    'vote': vote,
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    CalculationSection section,
    Color primaryText,
    Color secondaryText,
    Color dimColor,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            section.header,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: secondaryText,
            ),
          ),
        ),
        for (final line in section.lines)
          _buildLine(line, primaryText, secondaryText, dimColor, accentColor),
        // Narrative callout for cross-section references (e.g. sodium
        // inherits fluid floor/ceiling) or scenario-specific explanations
        // (redistribution / race deficit). Color variant picked from
        // `footerNoteVariant`.
        if (section.footerNote != null) ...[
          const SizedBox(height: 10),
          _buildFooterNote(
            section.footerNote!,
            section.footerNoteVariant,
            primaryText,
          ),
        ],
      ],
    );
  }

  Widget _buildLine(
    FormulaLine line,
    Color primaryText,
    Color secondaryText,
    Color dimColor,
    Color accentColor,
  ) {
    final spans = line.segments.map((seg) {
      Color color;
      FontWeight weight;
      switch (seg.style) {
        case SegmentStyle.accent:
          color = accentColor;
          weight = FontWeight.w600;
          break;
        case SegmentStyle.op:
          color = dimColor;
          weight = FontWeight.w400;
          break;
        case SegmentStyle.dim:
          color = secondaryText;
          weight = FontWeight.w400;
          break;
        case SegmentStyle.result:
          color = primaryText;
          weight = FontWeight.w700;
          break;
      }
      return TextSpan(
        text: seg.text,
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.6,
        ),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (line.stepNumber != null)
            SizedBox(
              width: 20,
              child: Text(
                line.stepNumber!,
                style: TextStyle(
                  fontSize: 12,
                  color: dimColor,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            )
          else
            const SizedBox(width: 20),
          Expanded(
            child: RichText(
              text: TextSpan(children: spans),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote(
    String note,
    CalcNoteVariant variant,
    Color primaryText,
  ) {
    // Color palette matches the Figma narrative-callout treatments:
    // blue info, purple redistribution, green success, amber warning.
    final Color accent = switch (variant) {
      CalcNoteVariant.info => const Color(0xFF4A9EFF),
      CalcNoteVariant.redistribution => const Color(0xFFB380FF),
      CalcNoteVariant.success => const Color(0xFF7BC67E),
      CalcNoteVariant.warning => const Color(0xFFF0C87E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Text(
        note,
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: primaryText.withValues(alpha: 0.85),
          height: 1.4,
        ),
      ),
    );
  }
}

/// "Does this make sense?" footer shown at the bottom of the Calculation
/// accordion. Tapping either thumb fires a Mixpanel event and swaps to a
/// small "Thanks!" confirmation.
class _CalcFeedbackFooter extends StatefulWidget {
  const _CalcFeedbackFooter({
    required this.nutrient,
    required this.phase,
    required this.onVote,
  });

  final String nutrient;
  final String phase;
  final ValueChanged<String> onVote;

  @override
  State<_CalcFeedbackFooter> createState() => _CalcFeedbackFooterState();
}

class _CalcFeedbackFooterState extends State<_CalcFeedbackFooter> {
  bool _voted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dim = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    if (_voted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: dim),
          const SizedBox(width: 4),
          Text(
            'Thanks for the feedback',
            style: TextStyle(
              fontSize: 11,
              color: dim,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Does this make sense?',
          style: TextStyle(
            fontSize: 12,
            color: dim,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 8),
        _CalcVoteButton(
          isUp: true,
          onTap: () {
            widget.onVote('up');
            setState(() => _voted = true);
          },
        ),
        const SizedBox(width: 4),
        _CalcVoteButton(
          isUp: false,
          onTap: () {
            widget.onVote('down');
            setState(() => _voted = true);
          },
        ),
      ],
    );
  }
}

class _CalcVoteButton extends StatelessWidget {
  const _CalcVoteButton({required this.isUp, required this.onTap});

  final bool isUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          isUp ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
          size: 15,
          color: color,
        ),
      ),
    );
  }
}
