import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/formula_pin_controller.dart';
import '../../domain/formula_phase.dart';
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
class PinToggleBefore extends ConsumerWidget {
  const PinToggleBefore({
    super.key,
    required this.formula,
    required this.source,
  });

  final BeforeFormulaView formula;

  /// Where the toggle lives — `'card'` for list cards, `'detail'` for the
  /// detail screen AppBar. Flows into the analytics payload.
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PinIconButton(
      isPinned: ref.watch(formulaPinControllerProvider).maybeWhen(
            data: (s) => s.pinnedTemplateIds.contains(formula.id),
            orElse: () => false,
          ),
      onTap: () async {
        try {
          await ref
              .read(formulaPinControllerProvider.notifier)
              .toggleBefore(formula: formula, source: source);
        } catch (e) {
          if (context.mounted) _showError(context, e);
        }
      },
    );
  }
}

class PinToggleDuring extends ConsumerWidget {
  const PinToggleDuring({
    super.key,
    required this.formula,
    required this.source,
  });

  final DuringFormulaView formula;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PinIconButton(
      isPinned: ref.watch(formulaPinControllerProvider).maybeWhen(
            data: (s) => s.pinnedTemplateIds.contains(formula.id),
            orElse: () => false,
          ),
      onTap: () async {
        try {
          await ref
              .read(formulaPinControllerProvider.notifier)
              .toggleDuring(formula: formula, source: source);
        } catch (e) {
          if (context.mounted) _showError(context, e);
        }
      },
    );
  }
}

class PinToggleAfter extends ConsumerWidget {
  const PinToggleAfter({
    super.key,
    required this.formula,
    required this.source,
  });

  final AfterFormulaView formula;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PinIconButton(
      isPinned: ref.watch(formulaPinControllerProvider).maybeWhen(
            data: (s) => s.pinnedTemplateIds.contains(formula.id),
            orElse: () => false,
          ),
      onTap: () async {
        try {
          await ref
              .read(formulaPinControllerProvider.notifier)
              .toggleAfter(formula: formula, source: source);
        } catch (e) {
          if (context.mounted) _showError(context, e);
        }
      },
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
    return _PinIconButton(
      isPinned: ref.watch(formulaPinControllerProvider).maybeWhen(
            data: (s) => s.pinnedTemplateIds.contains(formulaId),
            orElse: () => false,
          ),
      onTap: () async {
        try {
          await ref
              .read(formulaPinControllerProvider.notifier)
              .togglePersonalFormula(
                formulaId: formulaId,
                phase: phase,
                source: source,
              );
        } catch (e) {
          if (context.mounted) _showError(context, e);
        }
      },
    );
  }
}

class _PinIconButton extends StatelessWidget {
  const _PinIconButton({required this.isPinned, required this.onTap});

  final bool isPinned;
  final VoidCallback onTap;

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
          child: FaIcon(
            FontAwesomeIcons.thumbtack,
            size: 18,
            color: isPinned
                ? AppColors.orange
                : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  MealvanaSnackbar.showError(context, 'Couldn\'t update pin: $error');
}
