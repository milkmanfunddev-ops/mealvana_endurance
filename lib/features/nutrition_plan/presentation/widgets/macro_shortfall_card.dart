import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/cards/base_card.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../domain/macro_shortfall.dart';

/// Displays the gap between target and delivered macros for a phase, with
/// curated diet-aware suggestions and a CTA to adjust food preferences.
///
/// Rendered when the algorithm couldn't satisfy a macro target because user
/// preferences (dislikes, allergens, diet exclusions) eliminated viable foods.
/// Replaces what would otherwise be a silent zero or a forced-disliked food.
/// Issues #14 and #15.
///
/// Suggestions are picked from a small curated map keyed by macro + diet hint.
/// Falls back to "any source you tolerate" when no specific match exists.
class MacroShortfallCard extends StatelessWidget {
  const MacroShortfallCard({
    super.key,
    required this.shortfalls,
    this.dietHint,
    this.onAdjustPreferences,
  });

  /// One or more macro shortfalls to display in this card.
  final List<MacroShortfall> shortfalls;

  /// Optional diet identifier ('vegan', 'gluten_free', 'vegan+gluten_free',
  /// 'none') used to pick diet-appropriate food suggestions. When null the
  /// generic suggestion list is used.
  final String? dietHint;

  /// Tapped when the user wants to widen the algorithm's options. Typically
  /// navigates to the food preferences screen.
  final VoidCallback? onAdjustPreferences;

  @override
  Widget build(BuildContext context) {
    if (shortfalls.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BaseCard(
      backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.35),
      border: Border.all(
        color: colorScheme.error.withValues(alpha: 0.4),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colorScheme.error,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _headerText(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "We couldn't find foods matching all your preferences for this "
            'phase. The plan still includes what we could fit; consider '
            'topping up with one of these:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final s in shortfalls) ...[
            _ShortfallSuggestionsBlock(shortfall: s, dietHint: dietHint),
            if (s != shortfalls.last) const SizedBox(height: AppSpacing.sm),
          ],
          if (onAdjustPreferences != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdjustPreferences,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Adjust food preferences'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onErrorContainer,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headerText() {
    if (shortfalls.length == 1) {
      final s = shortfalls.first;
      final gap = s.gap.round();
      return '${_capitalize(s.macro.label)} gap: ~$gap${s.unit} short';
    }
    final macros = shortfalls.map((s) => s.macro.label).join(', ');
    return 'Macro gaps: $macros';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ShortfallSuggestionsBlock extends StatelessWidget {
  const _ShortfallSuggestionsBlock({
    required this.shortfall,
    required this.dietHint,
  });

  final MacroShortfall shortfall;
  final String? dietHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final suggestions = _suggestionsFor(shortfall.macro, dietHint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggestions for ${shortfall.macro.label}'
          '${dietHint != null && dietHint!.isNotEmpty ? ' ($dietHint)' : ''}:',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        for (final suggestion in suggestions)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '• $suggestion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer.withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
    );
  }

  /// Curated suggestions per (macro, diet hint). Kept in code for now —
  /// migrate to ContentService when the catalog grows. Always ends with
  /// "any X you tolerate" so the user knows they're not boxed in.
  static List<String> _suggestionsFor(ShortfallMacro macro, String? diet) {
    final isVegan = diet?.contains('vegan') ?? false;
    final isGF = diet?.contains('gluten') ?? false;

    switch (macro) {
      case ShortfallMacro.carbs:
        if (isVegan && isGF) {
          return const [
            '3-4 medjool dates (~30g carb)',
            '1 medium banana (~27g carb)',
            'Half cup applesauce (~25g carb)',
            'Or any carb source you tolerate',
          ];
        }
        if (isVegan) {
          return const [
            '3-4 medjool dates (~30g carb)',
            '1 slice toast + jam (~30g carb)',
            '1 medium banana (~27g carb)',
            'Or any vegan carb you tolerate',
          ];
        }
        return const [
          '1 medium banana (~27g carb)',
          '3-4 medjool dates (~30g carb)',
          'Half a bagel + honey (~30g carb)',
          'Or any carb source you tolerate',
        ];
      case ShortfallMacro.sodium:
        return const [
          'Pinch of salt on a snack (~250mg)',
          'Pickle juice shot (~900mg)',
          'Pretzels (~200mg per oz)',
          'Or any salty food you tolerate',
        ];
      case ShortfallMacro.fluid:
        return const [
          'Sip 200-300ml water now',
          'Coconut water (~240ml + electrolytes)',
          'Or any fluid you tolerate',
        ];
      case ShortfallMacro.protein:
        if (isVegan) {
          return const [
            'Soy/pea protein shake (~20g)',
            'Edamame (~17g per cup)',
            'Or any vegan protein you tolerate',
          ];
        }
        return const [
          'Greek yogurt (~17g per cup)',
          'Hard-boiled egg (~6g)',
          'Or any protein source you tolerate',
        ];
      case ShortfallMacro.caffeine:
        return const [
          'Half cup coffee (~50mg)',
          'Caffeinated gel (varies, 25-100mg)',
          'Or any caffeine source you tolerate',
        ];
    }
  }
}
