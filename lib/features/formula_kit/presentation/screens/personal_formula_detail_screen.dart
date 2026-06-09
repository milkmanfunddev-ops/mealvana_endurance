import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../application/personal_formulas_controller.dart';
import '../../domain/formula_macros.dart';
import '../../domain/personal_formula.dart';
import '../widgets/pin_toggle.dart';

/// Read-only detail for a user-authored personal formula, with pin toggle and
/// Edit / Delete affordances. Looks the formula up by [id] from the loaded
/// `personalFormulasControllerProvider` list (no separate fetch).
class PersonalFormulaDetailScreen extends ConsumerWidget {
  const PersonalFormulaDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFormulas = ref.watch(personalFormulasControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AdaptivePageScaffold(
      key: ValueKey('formula_kit.personal_detail_screen.$id'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      contentWidth: AdaptiveContentWidth.standard,
      appBar: asyncFormulas.maybeWhen(
        data: (formulas) {
          final formula = _find(formulas);
          return _buildAppBar(context, ref, formula);
        },
        orElse: () => AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const CustomAppBarBackButton(),
        ),
      ),
      body: asyncFormulas.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => Center(
          child: Text(
            'Couldn\'t load this formula.\n$e',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        data: (formulas) {
          final formula = _find(formulas);
          if (formula == null) {
            return Center(
              child: Text(
                'This formula no longer exists.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return _Body(formula: formula);
        },
      ),
    );
  }

  PersonalFormula? _find(List<PersonalFormula> formulas) =>
      formulas.cast<PersonalFormula?>().firstWhere(
            (f) => f?.id == id,
            orElse: () => null,
          );

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    PersonalFormula? formula,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(),
      title: Text(
        formula?.name ?? 'Formula',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: formula == null
          ? null
          : [
              PinTogglePersonalFormula(
                key: ValueKey('formula_kit.personal_detail_pin_$id'),
                formulaId: formula.id,
                phase: formula.phase,
                source: 'detail',
              ),
              PopupMenuButton<String>(
                key: const ValueKey('formula_kit.personal_detail_menu'),
                onSelected: (value) =>
                    _onMenu(context, ref, formula, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    PersonalFormula formula,
    String value,
  ) async {
    if (value == 'edit') {
      context.push(
        '/settings/food-preferences/formula-library/personal/${formula.id}/edit',
      );
      return;
    }
    if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete formula?'),
          content: Text('"${formula.name}" will be removed from Your Formulas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await ref
          .read(personalFormulasControllerProvider.notifier)
          .deleteFormula(formula.id);
      if (context.mounted) {
        MealvanaSnackbar.showSuccess(context, 'Formula deleted');
        context.pop();
      }
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.formula});

  final PersonalFormula formula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveScrollableBody(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Pill(
                label: formula.phase.displayLabel,
                color: AppColors.orange,
              ),
              _Pill(
                label: formula.provenance == FormulaProvenance.forkedFormula
                    ? 'Forked'
                    : 'From scratch',
                color: AppColors.electrolyte,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(formula: formula),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Components',
            style: AppTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (formula.components.isEmpty)
            _EmptyCard(text: 'No components yet.')
          else
            for (var i = 0; i < formula.components.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ComponentRow(component: formula.components[i]),
            ],
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Notes',
              style: AppTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.notes!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final Map<String, dynamic> component;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qty = FormulaMacros.quantityOf(component);
    final qtyStr = qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(1);
    final unit = component[FormulaMacros.kServingUnit] as String?;
    final totals = FormulaMacros.totalsForComponent(component);
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$qtyStr${unit != null && unit.isNotEmpty ? ' $unit' : ''} '
                    '${FormulaMacros.nameOf(component)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${totals.carbsG}g C · ${totals.proteinG}g P · '
                    '${totals.fatG}g F · ${totals.sodiumMg}mg Na',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacrosCard extends StatelessWidget {
  const _MacrosCard({required this.formula});

  final PersonalFormula formula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, String value) => Column(
          children: [
            Text(
              value,
              style: AppTextStyles.dataNumber.copyWith(
                color: AppColors.electrolyte,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            cell('Cal', '${formula.totalCalories ?? 0}'),
            cell('Carbs', '${formula.totalCarbsG ?? 0}g'),
            cell('Protein', '${formula.totalProteinG ?? 0}g'),
            cell('Fat', '${formula.totalFatG ?? 0}g'),
            cell('Na', '${formula.totalSodiumMg ?? 0}'),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
