import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/formula_pin_controller.dart';
import '../../domain/formula_phase.dart';
import '../../domain/formula_profile_conflict.dart';
import '../../domain/formula_view.dart';

/// Single-tap pin toggle for a system formula. Used on library cards and
/// the detail screen AppBar.
///
/// Optimistic UI: the icon flips immediately on tap; the controller calls
/// the Drift write in the background. On failure the controller reverts
/// state and surfaces a snackbar via [_showError].
///
/// V1 policy: pins are food templates only. Drink/electrolyte cards
/// (`templateType != 'food'`) must NOT render this widget — call sites
/// should gate on `formula.isPinnable`.
///
/// Conflict gate (FP-4a/4b, `formula-pin-surface.md`, RATIFIED Xuan
/// 2026-09-03): when [conflict] is supplied, pinning an ALLERGY-conflicted
/// formula routes through [onAllergyConflictPinAttempt] instead of pinning
/// (the owner mounts the inline in-card warning; "Pin anyway" completes the
/// pin), while a DIET conflict pins normally and then informs via
/// [onDietConflictPinned]. A pinned conflicted formula's glyph carries a
/// small dragonfruit conflict dot. All three are optional — omitting them
/// keeps the pre-FP behavior (detail-screen AppBar passes conflict for the
/// dot; unpinning is never gated).
class PinToggleBefore extends ConsumerWidget {
  const PinToggleBefore({
    super.key,
    required this.formula,
    required this.source,
    this.conflict,
    this.onAllergyConflictPinAttempt,
    this.onDietConflictPinned,
  });

  final BeforeFormulaView formula;

  /// Where the toggle lives — `'card'` for list cards, `'detail'` for the
  /// detail screen AppBar. Flows into the analytics payload.
  final String source;

  final FormulaProfileConflict? conflict;
  final VoidCallback? onAllergyConflictPinAttempt;
  final VoidCallback? onDietConflictPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _conflictAwarePinButton(
      context: context,
      ref: ref,
      templateId: formula.id,
      conflict: conflict,
      onAllergyConflictPinAttempt: onAllergyConflictPinAttempt,
      onDietConflictPinned: onDietConflictPinned,
      toggle: () => ref
          .read(formulaPinControllerProvider.notifier)
          .toggleBefore(formula: formula, source: source),
    );
  }
}

class PinToggleDuring extends ConsumerWidget {
  const PinToggleDuring({
    super.key,
    required this.formula,
    required this.source,
    this.conflict,
    this.onAllergyConflictPinAttempt,
    this.onDietConflictPinned,
  });

  final DuringFormulaView formula;
  final String source;
  final FormulaProfileConflict? conflict;
  final VoidCallback? onAllergyConflictPinAttempt;
  final VoidCallback? onDietConflictPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _conflictAwarePinButton(
      context: context,
      ref: ref,
      templateId: formula.id,
      conflict: conflict,
      onAllergyConflictPinAttempt: onAllergyConflictPinAttempt,
      onDietConflictPinned: onDietConflictPinned,
      toggle: () => ref
          .read(formulaPinControllerProvider.notifier)
          .toggleDuring(formula: formula, source: source),
    );
  }
}

class PinToggleAfter extends ConsumerWidget {
  const PinToggleAfter({
    super.key,
    required this.formula,
    required this.source,
    this.conflict,
    this.onAllergyConflictPinAttempt,
    this.onDietConflictPinned,
  });

  final AfterFormulaView formula;
  final String source;
  final FormulaProfileConflict? conflict;
  final VoidCallback? onAllergyConflictPinAttempt;
  final VoidCallback? onDietConflictPinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _conflictAwarePinButton(
      context: context,
      ref: ref,
      templateId: formula.id,
      conflict: conflict,
      onAllergyConflictPinAttempt: onAllergyConflictPinAttempt,
      onDietConflictPinned: onDietConflictPinned,
      toggle: () => ref
          .read(formulaPinControllerProvider.notifier)
          .toggleAfter(formula: formula, source: source),
    );
  }
}

/// Pin toggle for a user-authored personal formula. Unlike the system
/// variants, the phase is carried explicitly (it lives on the formula, not on
/// the [TemplateKind]) so it can flow into the analytics payload.
class PinTogglePersonalFormula extends ConsumerWidget {
  const PinTogglePersonalFormula({
    super.key,
    required this.formulaId,
    required this.phase,
    required this.source,
  });

  final String formulaId;
  final FormulaPhase phase;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _conflictAwarePinButton(
      context: context,
      ref: ref,
      templateId: formulaId,
      conflict: null,
      onAllergyConflictPinAttempt: null,
      onDietConflictPinned: null,
      toggle: () => ref
          .read(formulaPinControllerProvider.notifier)
          .togglePersonalFormula(
            formulaId: formulaId,
            phase: phase,
            source: source,
          ),
    );
  }
}

/// Shared build for all four toggle variants: reads the pinned state, routes
/// an allergy-conflicted PIN attempt to the owner's inline warning (FP-4a),
/// lets a diet-conflicted pin proceed with a follow-up note, and shows the
/// conflict dot on a pinned conflicted formula (FP-4b). Unpin taps are never
/// intercepted.
Widget _conflictAwarePinButton({
  required BuildContext context,
  required WidgetRef ref,
  required String templateId,
  required FormulaProfileConflict? conflict,
  required VoidCallback? onAllergyConflictPinAttempt,
  required VoidCallback? onDietConflictPinned,
  required Future<void> Function() toggle,
}) {
  final isPinned = ref
      .watch(formulaPinControllerProvider)
      .maybeWhen(
        data: (s) => s.pinnedTemplateIds.contains(templateId),
        orElse: () => false,
      );
  return _PinIconButton(
    isPinned: isPinned,
    showConflictDot: isPinned && conflict != null,
    onTap: () async {
      final isPinning = !isPinned;
      if (isPinning &&
          conflict?.kind == FormulaConflictKind.allergy &&
          onAllergyConflictPinAttempt != null) {
        // Decision moment: hand off to the in-card warning instead of
        // pinning. "Pin anyway" completes the pin from the warning.
        onAllergyConflictPinAttempt();
        return;
      }
      try {
        await toggle();
      } catch (e) {
        if (context.mounted) _showError(context, e);
        return;
      }
      if (isPinning && conflict?.kind == FormulaConflictKind.diet) {
        // The pin proceeds; the softer note informs (R-02 option 1).
        onDietConflictPinned?.call();
      }
    },
  );
}

class _PinIconButton extends StatelessWidget {
  const _PinIconButton({
    required this.isPinned,
    required this.onTap,
    this.showConflictDot = false,
  });

  final bool isPinned;
  final VoidCallback onTap;

  /// FP-4b: an honored conflicting pin's glyph carries a small dragonfruit
  /// conflict dot.
  final bool showConflictDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isPinned ? 'Unpin formula' : 'Pin formula',
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          // FA Free 11 ships only the solid `thumbtack`; we communicate
          // pinned/unpinned via color (orange fill vs muted) rather than
          // swapping outline/solid glyphs.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FaIcon(
                FontAwesomeIcons.thumbtack,
                size: 18,
                color: isPinned
                    ? AppColors.orange
                    : scheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              if (showConflictDot)
                Positioned(
                  top: -2,
                  right: -3,
                  child: Container(
                    key: const ValueKey('formula_kit.pin_conflict_dot'),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.dragonfruit,
                      shape: BoxShape.circle,
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

void _showError(BuildContext context, Object error) {
  MealvanaSnackbar.showError(context, 'Couldn\'t update pin: $error');
}
