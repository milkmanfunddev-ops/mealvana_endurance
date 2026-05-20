import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../onboarding/domain/dietary_preference.dart';
import '../../application/formula_library_controller.dart';
import '../../domain/before_sub_phase.dart';
import '../../domain/during_filter_options.dart';
import '../../domain/formula_phase.dart';

/// Bottom sheet that surfaces the Formula Library's "More filters" controls.
///
/// V1 (PR 1) exposes the filter fields that the controller already manages:
///   - Before phase: digestion speed (Fast / Medium / Slow)
///   - During phase: gut training level (Low / Moderate / High)
///   - Both phases: "Show all formulas (ignore my dietary profile)" toggle
///
/// Multi-select diet / allergen pickers and the "Favorites only" chip ship in
/// later PRs and will hang off the same controller without restructuring this
/// sheet — sections will be added in-place.
class MoreFiltersSheet extends ConsumerWidget {
  const MoreFiltersSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MoreFiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(formulaLibraryControllerProvider);
    final controller = ref.read(formulaLibraryControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return asyncState.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (state) {
        final phase = state.filter.phase;
        return Container(
          key: const ValueKey('formula_kit.more_filters_sheet'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'More filters',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('formula_kit.more_filters.reset'),
                        onPressed: state.filter.activeMoreFilterCount == 0
                            ? null
                            : () => controller.clearMoreFilters(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.orange,
                          disabledForegroundColor:
                              scheme.onSurface.withValues(alpha: 0.35),
                        ),
                        child: Text(
                          'Reset',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (phase == FormulaPhase.before)
                          _Section(
                            label: 'Digestion speed',
                            child: _ChipWrap(
                              children: [
                                for (final v in FormulaDigestionSpeed.values)
                                  _Chip(
                                    key: ValueKey(
                                      'formula_kit.more_filters.digestion.${v.name}',
                                    ),
                                    label: v.displayLabel,
                                    selected:
                                        state.filter.beforeDigestionSpeed == v,
                                    onTap: () => controller
                                        .toggleBeforeDigestionSpeed(v),
                                  ),
                              ],
                            ),
                          )
                        else
                          _Section(
                            label: 'Gut training level',
                            child: _ChipWrap(
                              children: [
                                for (final v in DuringGutLevel.values)
                                  _Chip(
                                    key: ValueKey(
                                      'formula_kit.more_filters.gut_level.${v.name}',
                                    ),
                                    label: v.displayLabel,
                                    selected: state.filter.duringGutLevel == v,
                                    onTap: () =>
                                        controller.toggleDuringGutLevel(v),
                                  ),
                              ],
                            ),
                          ),
                        if (state.userAllergies.isNotEmpty ||
                            state.userDiets
                                .any((d) => d != DietaryPreference.none)) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _Section(
                            label: 'Dietary profile',
                            child: _ChipWrap(
                              children: [
                                // One chip per dietary preference from the
                                // profile (skip `.none`). Selected = applying
                                // this restriction (default state).
                                for (final d in state.userDiets)
                                  if (d != DietaryPreference.none)
                                    _Chip(
                                      key: ValueKey(
                                        'formula_kit.more_filters.diet.${d.dbValue}',
                                      ),
                                      label: d.displayName,
                                      selected: !state.filter.bypassedDiets
                                          .contains(d),
                                      onTap: () =>
                                          controller.toggleDietBypass(d),
                                    ),
                                // One chip per allergy from the profile.
                                for (final a in state.userAllergies)
                                  _Chip(
                                    key: ValueKey(
                                      'formula_kit.more_filters.allergy.${a.dbValue}',
                                    ),
                                    label: a.displayName,
                                    selected: !state.filter.bypassedAllergies
                                        .contains(a),
                                    onTap: () =>
                                        controller.toggleAllergyBypass(a),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: KylePrimaryButton(
                    key: const ValueKey('formula_kit.more_filters.apply'),
                    text: 'Apply',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: children,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? AppColors.electrolyte.withValues(alpha: 0.25)
        : scheme.surfaceContainerHighest;
    final border = selected ? AppColors.electrolyte : scheme.outlineVariant;
    return Material(
      color: bg,
      borderRadius: AppRadius.circularRadius,
      child: InkWell(
        borderRadius: AppRadius.circularRadius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.circularRadius,
            border: Border.all(color: border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
