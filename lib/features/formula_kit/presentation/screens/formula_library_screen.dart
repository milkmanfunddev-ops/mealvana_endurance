import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../application/formula_library_controller.dart';
import '../../domain/before_sub_phase.dart';
import '../../domain/during_filter_options.dart';
import '../../domain/formula_phase.dart';
import '../widgets/before_formula_card.dart';
import '../widgets/during_formula_card.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/phase_tab_bar.dart';

/// Browse screen for the Formula Library (PR 1 of Formula Kit).
///
/// Provides:
///   - Phase tabs (Before / During)
///   - Per-phase filter chip row (Timing / Activity + Duration)
///   - Read-only formula cards that route to the detail screen
///
/// Personalization / favorites / create flows land in PR 2-5.
class FormulaLibraryScreen extends ConsumerStatefulWidget {
  const FormulaLibraryScreen({super.key});

  @override
  ConsumerState<FormulaLibraryScreen> createState() =>
      _FormulaLibraryScreenState();
}

class _FormulaLibraryScreenState extends ConsumerState<FormulaLibraryScreen> {
  bool _trackedOpen = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(formulaLibraryControllerProvider);

    // Fire entry-point analytics once per screen instance, after first frame.
    if (!_trackedOpen) {
      _trackedOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(formulaLibraryControllerProvider.notifier)
            .trackLibraryOpened(source: 'food_preferences_hub');
      });
    }

    return AdaptivePageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          'Formula Library',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      contentWidth: AdaptiveContentWidth.standard,
      body: asyncState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final FormulaLibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(formulaLibraryControllerProvider.notifier);
    final phase = state.filter.phase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PhaseTabBar(
            selected: phase,
            onSelected: controller.setPhase,
          ),
        ),
        if (phase == FormulaPhase.before)
          FilterChipRow<BeforeSubPhase>(
            options: BeforeSubPhase.values,
            labelOf: (v) => v.displayLabel,
            isSelected: (v) => state.filter.beforeSubPhase == v,
            onToggled: controller.toggleBeforeSubPhase,
          )
        else ...[
          FilterChipRow<DuringActivity>(
            options: DuringActivity.values,
            labelOf: (v) => v.displayLabel,
            isSelected: (v) => state.filter.duringActivity == v,
            onToggled: controller.toggleDuringActivity,
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipRow<DuringDuration>(
            options: DuringDuration.values,
            labelOf: (v) => v.displayLabel,
            isSelected: (v) => state.filter.duringDuration == v,
            onToggled: controller.toggleDuringDuration,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: phase == FormulaPhase.before
              ? _BeforeList(formulas: state.filteredBeforeFormulas)
              : _DuringList(formulas: state.filteredDuringFormulas),
        ),
      ],
    );
  }
}

class _BeforeList extends StatelessWidget {
  const _BeforeList({required this.formulas});

  final List<dynamic> formulas;

  @override
  Widget build(BuildContext context) {
    if (formulas.isEmpty) {
      return const _EmptyState(
        message: 'No Before formulas match your filters.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      itemCount: formulas.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final f = formulas[i];
        return BeforeFormulaCard(
          formula: f,
          onTap: () => context.push(
            '/settings/food-preferences/formula-library/before/${f.id}',
          ),
        );
      },
    );
  }
}

class _DuringList extends StatelessWidget {
  const _DuringList({required this.formulas});

  final List<dynamic> formulas;

  @override
  Widget build(BuildContext context) {
    if (formulas.isEmpty) {
      return const _EmptyState(
        message: 'No During formulas match your filters.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl,
      ),
      itemCount: formulas.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final f = formulas[i];
        return DuringFormulaCard(
          formula: f,
          onTap: () => context.push(
            '/settings/food-preferences/formula-library/during/${f.id}',
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.filter,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              FontAwesomeIcons.circleExclamation,
              color: AppColors.dragonfruit,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load formulas',
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.dragonfruit,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
