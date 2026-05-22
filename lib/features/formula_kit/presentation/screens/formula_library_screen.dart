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
import '../widgets/collapsible_header.dart';
import '../widgets/during_formula_card.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/more_filters_sheet.dart';
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

    final moreFilterCount = asyncState.maybeWhen(
      data: (s) => s.activeMoreFilterCount,
      orElse: () => 0,
    );

    return AdaptivePageScaffold(
      key: const ValueKey('formula_kit.library_screen'),
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
        actions: [
          _MoreFiltersButton(activeCount: moreFilterCount),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      contentWidth: AdaptiveContentWidth.standard,
      body: asyncState.when(
        loading: () => const Center(
          key: ValueKey('formula_kit.library_loading'),
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.state});

  final FormulaLibraryState state;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  /// Whether the filter header is currently collapsed by list scroll.
  /// Pure UI state — does not belong on the controller.
  bool _collapsed = false;

  /// Hysteresis: collapse only after scrolling past [_collapseAt] pixels and
  /// re-expand only when scroll returns above [_expandAt]. The gap prevents
  /// rapid flip-flopping near the threshold.
  static const double _collapseAt = 24;
  static const double _expandAt = 8;

  @override
  void didUpdateWidget(_Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Phase switch should re-show the header so the user sees the new chips.
    if (oldWidget.state.filter.phase != widget.state.filter.phase &&
        _collapsed) {
      setState(() => _collapsed = false);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification) return false;
    final offset = n.metrics.pixels;
    if (offset > _collapseAt && !_collapsed) {
      setState(() => _collapsed = true);
    } else if (offset < _expandAt && _collapsed) {
      setState(() => _collapsed = false);
    }
    return false;
  }

  List<String> _activeFilterLabels() {
    final f = widget.state.filter;
    if (f.phase == FormulaPhase.before) {
      return [
        if (f.beforeSubPhase != null) f.beforeSubPhase!.displayLabel,
      ];
    }
    return [
      if (f.duringActivity != null) f.duringActivity!.displayLabel,
      if (f.duringDuration != null) f.duringDuration!.displayLabel,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(formulaLibraryControllerProvider.notifier);
    final phase = state.filter.phase;

    final visibleCount = phase == FormulaPhase.before
        ? state.filteredBeforeFormulas.length
        : state.filteredDuringFormulas.length;
    final totalCount = phase == FormulaPhase.before
        ? state.beforeFormulas.length
        : state.duringFormulas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollapsibleHeader(
          collapsed: _collapsed,
          child: Column(
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
                  key: const ValueKey('formula_kit.chip_row.before_sub_phase'),
                  options: BeforeSubPhase.values,
                  labelOf: (v) => v.displayLabel,
                  keyOf: (v) =>
                      ValueKey('formula_kit.chip.before_sub_phase.${v.name}'),
                  isSelected: (v) => state.filter.beforeSubPhase == v,
                  onToggled: controller.toggleBeforeSubPhase,
                )
              else ...[
                FilterChipRow<DuringActivity>(
                  key: const ValueKey('formula_kit.chip_row.during_activity'),
                  options: DuringActivity.values,
                  labelOf: (v) => v.displayLabel,
                  keyOf: (v) =>
                      ValueKey('formula_kit.chip.during_activity.${v.name}'),
                  isSelected: (v) => state.filter.duringActivity == v,
                  onToggled: controller.toggleDuringActivity,
                ),
                const SizedBox(height: AppSpacing.xs),
                FilterChipRow<DuringDuration>(
                  key: const ValueKey('formula_kit.chip_row.during_duration'),
                  options: DuringDuration.values,
                  labelOf: (v) => v.displayLabel,
                  keyOf: (v) =>
                      ValueKey('formula_kit.chip.during_duration.${v.name}'),
                  isSelected: (v) => state.filter.duringDuration == v,
                  onToggled: controller.toggleDuringDuration,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        if (_collapsed)
          CollapsedStrip(
            key: const ValueKey('formula_kit.collapsed_strip'),
            phaseLabel: phase.displayLabel,
            activeFilters: _activeFilterLabels(),
            visibleCount: visibleCount,
            totalCount: totalCount,
            onExpand: () => setState(() => _collapsed = false),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: phase == FormulaPhase.before
                ? _BeforeList(formulas: state.filteredBeforeFormulas)
                : _DuringList(formulas: state.filteredDuringFormulas),
          ),
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
        key: ValueKey('formula_kit.before_empty_state'),
        message: 'No Before formulas match your filters.',
      );
    }
    return ListView.separated(
      key: const ValueKey('formula_kit.before_list'),
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
          key: ValueKey('formula_kit.before_card_${f.id}'),
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
        key: ValueKey('formula_kit.during_empty_state'),
        message: 'No During formulas match your filters.',
      );
    }
    return ListView.separated(
      key: const ValueKey('formula_kit.during_list'),
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
          key: ValueKey('formula_kit.during_card_${f.id}'),
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
  const _EmptyState({super.key, required this.message});

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
            FaIcon(
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

/// AppBar trailing action that opens the More Filters sheet. Shows a small
/// orange badge with the active More-Filter count when any are applied.
class _MoreFiltersButton extends StatelessWidget {
  const _MoreFiltersButton({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasActive = activeCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Material(
        color: hasActive
            ? AppColors.orange.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadius.circularRadius,
        child: InkWell(
          key: const ValueKey('formula_kit.more_filters_button'),
          borderRadius: AppRadius.circularRadius,
          onTap: () => MoreFiltersSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.sliders,
                  size: 14,
                  color: hasActive ? AppColors.orange : scheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasActive ? AppColors.orange : scheme.onSurface,
                  ),
                ),
                if (hasActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const ValueKey('formula_kit.more_filters_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$activeCount',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackberry,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
      key: const ValueKey('formula_kit.library_error'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
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
