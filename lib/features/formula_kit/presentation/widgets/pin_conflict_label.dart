import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_profile_conflict.dart';

/// FP-4b post-pin label — `formula-pin-surface.md` (RATIFIED Xuan,
/// 2026-09-03). A persistent, COLLAPSIBLE label in `dragonfruit`
/// (Q-D9-conformant) on an honored pin that conflicts with the profile:
///
///   - collapsed: one line, e.g. "Pinned despite your gluten allergy"
///   - expanded: the §1a policy sentence + **Keep pin / Unpin**
///
/// PRESENTATION ONLY: a pin is never auto-removed when the profile changes —
/// this label is how the allergies-changed-after-pin case stays honest.
class PinConflictLabel extends StatefulWidget {
  const PinConflictLabel({
    super.key,
    required this.conflict,
    required this.onUnpin,
    this.initiallyExpanded = false,
  });

  final FormulaProfileConflict conflict;

  /// Removes the pin through the owning controller. "Keep pin" simply
  /// collapses the label — the pin itself is untouched either way until the
  /// user explicitly unpins.
  final VoidCallback onUnpin;

  final bool initiallyExpanded;

  @override
  State<PinConflictLabel> createState() => _PinConflictLabelState();
}

class _PinConflictLabelState extends State<PinConflictLabel> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('formula_kit.pin_conflict_label'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dragonfruit.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('formula_kit.pin_conflict_label_header'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  // The conflict dot, echoed from the pin glyph (FP-4b).
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.dragonfruit,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      conflictLabelCollapsedText(widget.conflict),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dragonfruit,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.dragonfruit,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pinPolicySentence,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey(
                          'formula_kit.pin_conflict_label_keep',
                        ),
                        onPressed: () => setState(() => _expanded = false),
                        child: const Text('Keep pin'),
                      ),
                      TextButton(
                        key: const ValueKey(
                          'formula_kit.pin_conflict_label_unpin',
                        ),
                        onPressed: widget.onUnpin,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.dragonfruit,
                        ),
                        child: const Text('Unpin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
