import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../application/formula_library_controller.dart';
import '../../application/formula_pin_controller.dart';
import '../../application/personal_formulas_controller.dart';
import '../../domain/after_filter_options.dart';
import '../../domain/before_sub_phase.dart';
import '../../domain/during_filter_options.dart';
import '../../domain/formula_phase.dart';
import '../../domain/formula_view.dart';
import '../../domain/personal_formula.dart';
import '../widgets/after_formula_card.dart';
import '../widgets/before_formula_card.dart';
import '../widgets/collapsible_header.dart';
import '../widgets/during_formula_card.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/more_filters_sheet.dart';
import '../widgets/personal_formula_card.dart';
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
          const _PinnedOnlyButton(),
          const SizedBox(width: AppSpacing.xs),
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
    if (f.phase == FormulaPhase.during) {
      return [
        if (f.duringActivity != null) f.duringActivity!.displayLabel,
        if (f.duringDuration != null) f.duringDuration!.displayLabel,
      ];
    }
    // After: single-select chip — surface the active value when set.
    return [
      if (f.afterTravelFriendliness != null)
        f.afterTravelFriendliness!.displayLabel,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = ref.read(formulaLibraryControllerProvider.notifier);
    final phase = state.filter.phase;

    // Pinned-only stacks on top of the controller's chip/dietary filters
    // (Q3a from design). We do the pin filtering here so the controller stays
    // decoupled from the pin store — the screen composes both providers.
    final pinIds = ref.watch(formulaPinControllerProvider).maybeWhen(
          data: (s) => s.pinnedTemplateIds,
          orElse: () => const <String>{},
        );
    final pinnedOnly = state.filter.pinnedOnly;

    final visibleBefore = pinnedOnly
        ? state.filteredBeforeFormulas
            .where((f) => pinIds.contains(f.id))
            .toList()
        : state.filteredBeforeFormulas;
    final visibleDuring = pinnedOnly
        ? state.filteredDuringFormulas
            .where((f) => pinIds.contains(f.id))
            .toList()
        : state.filteredDuringFormulas;
    final visibleAfter = pinnedOnly
        ? state.filteredAfterFormulas
            .where((f) => pinIds.contains(f.id))
            .toList()
        : state.filteredAfterFormulas;

    // Pin counts per phase from the *unfiltered* lists, used by empty-state
    // copy to differentiate "you have no pins" from "your pins don't match
    // these filters."
    final pinnedBeforeCount =
        state.beforeFormulas.where((f) => pinIds.contains(f.id)).length;
    final pinnedDuringCount =
        state.duringFormulas.where((f) => pinIds.contains(f.id)).length;
    final pinnedAfterCount =
        state.afterFormulas.where((f) => pinIds.contains(f.id)).length;

    final visibleCount = switch (phase) {
      FormulaPhase.before => visibleBefore.length,
      FormulaPhase.during => visibleDuring.length,
      FormulaPhase.after => visibleAfter.length,
    };
    final totalCount = switch (phase) {
      FormulaPhase.before => state.beforeFormulas.length,
      FormulaPhase.during => state.duringFormulas.length,
      FormulaPhase.after => state.afterFormulas.length,
    };

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
              else if (phase == FormulaPhase.during) ...[
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
              ] else
                // Multi-select chip row: tapping toggles a value's membership
                // in the active set. Defaults to all three included (no
                // filter); see `FormulaFilterState.afterTravelFriendliness`.
                FilterChipRow<TravelFriendliness>(
                  key: const ValueKey(
                    'formula_kit.chip_row.after_travel_friendliness',
                  ),
                  options: TravelFriendliness.values,
                  labelOf: (v) => v.displayLabel,
                  keyOf: (v) => ValueKey(
                    'formula_kit.chip.after_travel_friendliness.${v.name}',
                  ),
                  isSelected: (v) =>
                      state.filter.afterTravelFriendliness == v,
                  onToggled: controller.toggleAfterTravelFriendliness,
                ),
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
            child: switch (phase) {
              FormulaPhase.before => _BeforeList(
                  formulas: visibleBefore,
                  pinnedOnly: pinnedOnly,
                  pinnedInPhaseCount: pinnedBeforeCount,
                ),
              FormulaPhase.during => _DuringList(
                  formulas: visibleDuring,
                  pinnedOnly: pinnedOnly,
                  pinnedInPhaseCount: pinnedDuringCount,
                ),
              FormulaPhase.after => _AfterList(
                  formulas: visibleAfter,
                  pinnedOnly: pinnedOnly,
                  pinnedInPhaseCount: pinnedAfterCount,
                ),
            },
          ),
        ),
      ],
    );
  }
}

/// Leading "Your Formulas" section shared by every phase list — a header with
/// a "+ New" entry point and the user's personal formulas for [phase], above
/// the read-only system "Library" section.
List<Widget> _yourFormulasSection(
  BuildContext context,
  WidgetRef ref,
  FormulaPhase phase,
) {
  final scheme = Theme.of(context).colorScheme;

  // Apply the same active chip / pinned-only filters the system lists use, so
  // "Your Formulas" filters in step with the rest of the screen.
  final filter = ref.watch(formulaLibraryControllerProvider).value?.filter;
  final pinIds = ref.watch(formulaPinControllerProvider).maybeWhen(
        data: (s) => s.pinnedTemplateIds,
        orElse: () => const <String>{},
      );

  bool matchesFilter(PersonalFormula f) {
    if (filter == null) return true;
    if (filter.pinnedOnly && !pinIds.contains(f.id)) return false;
    switch (phase) {
      case FormulaPhase.before:
        final sp = filter.beforeSubPhase;
        if (sp != null && f.subPhase != sp.storageValue) return false;
        final ds = filter.beforeDigestionSpeed;
        if (ds != null && f.digestSpeed != ds.storageValue) return false;
      case FormulaPhase.during:
        final a = filter.duringActivity;
        if (a != null && !(f.activities?.contains(a.storageValue) ?? false)) {
          return false;
        }
        final d = filter.duringDuration;
        if (d != null && !(f.durations?.contains(d.storageValue) ?? false)) {
          return false;
        }
        final g = filter.duringGutLevel;
        if (g != null && f.gutTraining != g.storageValue) return false;
      case FormulaPhase.after:
        final t = filter.afterTravelFriendliness;
        if (t != null && f.travelFriendliness != t.storageValue) return false;
    }
    return true;
  }

  final personal = ref.watch(personalFormulasControllerProvider).maybeWhen(
        data: (all) => all
            .where((f) => f.phase == phase)
            .where(matchesFilter)
            .toList(growable: false),
        orElse: () => const <PersonalFormula>[],
      );

  return [
    Row(
      children: [
        Expanded(
          child: Text(
            'Your Formulas',
            style: AppTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
        TextButton.icon(
          key: ValueKey(
            'formula_kit.your_formulas_new_${phase.analyticsValue}',
          ),
          onPressed: () {
            ref.read(formulaLibraryControllerProvider.notifier).trackCreateStarted(
                  phase: phase,
                  source: 'library_new_button',
                );
            context.push(
              '/settings/food-preferences/formula-library/personal/create',
              extra: {'phase': phase},
            );
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New'),
        ),
      ],
    ),
    if (personal.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          'Build your own ${phase.displayLabel.toLowerCase()} formula and pin '
          'it so your plans use it.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: scheme.onSurfaceVariant),
        ),
      )
    else
      for (final f in personal)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          // Swipe left to delete (with confirm). No overflow/hamburger menu —
          // tapping the card opens the editor.
          child: Dismissible(
            key: ValueKey('formula_kit.personal_dismiss_${f.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.dragonfruit,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Delete',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.delete_outline, color: Colors.white),
                ],
              ),
            ),
            // Confirm + delete via state rebuild; return false so the
            // Dismissible itself never animates away (avoids double-removal).
            confirmDismiss: (_) async {
              await _confirmDeletePersonalFormula(context, ref, f);
              return false;
            },
            child: PersonalFormulaCard(
              key: ValueKey('formula_kit.personal_card_${f.id}'),
              formula: f,
              // Tap opens the editor directly (personal/:id IS the editor now).
              onTap: () => context.push(
                '/settings/food-preferences/formula-library/personal/${f.id}',
              ),
            ),
          ),
        ),
    const SizedBox(height: AppSpacing.sm),
    Text(
      'Library',
      style: AppTextStyles.sectionTitle.copyWith(color: scheme.onSurface),
    ),
    const SizedBox(height: AppSpacing.xs),
  ];
}

/// Confirm + delete a personal formula from the Your Formulas list. Shared by
/// the card overflow menu (and mirrors the detail-screen delete).
Future<void> _confirmDeletePersonalFormula(
  BuildContext context,
  WidgetRef ref,
  PersonalFormula formula,
) async {
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
  }
}

const _listPadding = EdgeInsets.fromLTRB(
  AppSpacing.md,
  AppSpacing.sm,
  AppSpacing.md,
  AppSpacing.xxxl,
);

class _BeforeList extends ConsumerWidget {
  const _BeforeList({
    required this.formulas,
    required this.pinnedOnly,
    required this.pinnedInPhaseCount,
  });

  final List<BeforeFormulaView> formulas;
  final bool pinnedOnly;
  final int pinnedInPhaseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('formula_kit.before_list'),
      padding: _listPadding,
      children: [
        ..._yourFormulasSection(context, ref, FormulaPhase.before),
        if (formulas.isEmpty)
          SizedBox(
            height: 320,
            child: _LibraryEmptyState(
              phase: FormulaPhase.before,
              pinnedOnly: pinnedOnly,
              pinnedInPhaseCount: pinnedInPhaseCount,
            ),
          )
        else
          for (final f in formulas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: BeforeFormulaCard(
                key: ValueKey('formula_kit.before_card_${f.id}'),
                formula: f,
                onTap: () => context.push(
                  '/settings/food-preferences/formula-library/before/${f.id}',
                ),
              ),
            ),
      ],
    );
  }
}

class _DuringList extends ConsumerWidget {
  const _DuringList({
    required this.formulas,
    required this.pinnedOnly,
    required this.pinnedInPhaseCount,
  });

  final List<DuringFormulaView> formulas;
  final bool pinnedOnly;
  final int pinnedInPhaseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('formula_kit.during_list'),
      padding: _listPadding,
      children: [
        ..._yourFormulasSection(context, ref, FormulaPhase.during),
        if (formulas.isEmpty)
          SizedBox(
            height: 320,
            child: _LibraryEmptyState(
              phase: FormulaPhase.during,
              pinnedOnly: pinnedOnly,
              pinnedInPhaseCount: pinnedInPhaseCount,
            ),
          )
        else
          for (final f in formulas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DuringFormulaCard(
                key: ValueKey('formula_kit.during_card_${f.id}'),
                formula: f,
                onTap: () => context.push(
                  '/settings/food-preferences/formula-library/during/${f.id}',
                ),
              ),
            ),
      ],
    );
  }
}

class _AfterList extends ConsumerWidget {
  const _AfterList({
    required this.formulas,
    required this.pinnedOnly,
    required this.pinnedInPhaseCount,
  });

  final List<AfterFormulaView> formulas;
  final bool pinnedOnly;
  final int pinnedInPhaseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      key: const ValueKey('formula_kit.after_list'),
      padding: _listPadding,
      children: [
        ..._yourFormulasSection(context, ref, FormulaPhase.after),
        if (formulas.isEmpty)
          SizedBox(
            height: 320,
            child: _LibraryEmptyState(
              phase: FormulaPhase.after,
              pinnedOnly: pinnedOnly,
              pinnedInPhaseCount: pinnedInPhaseCount,
            ),
          )
        else
          for (final f in formulas)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AfterFormulaCard(
                key: ValueKey('formula_kit.after_card_${f.id}'),
                formula: f,
                onTap: () => context.push(
                  '/settings/food-preferences/formula-library/after/${f.id}',
                ),
              ),
            ),
      ],
    );
  }
}

/// Empty-state router. Differentiates:
///   - pinned-only with **no pins at all** in this phase → onboarding nudge
///     ("Tap the thumbtack to pin one")
///   - pinned-only with pins but **none match active filters** → action to
///     clear the chip + dietary filters while keeping pinned-only on
///   - normal filter no-match → original copy
class _LibraryEmptyState extends ConsumerWidget {
  const _LibraryEmptyState({
    required this.phase,
    required this.pinnedOnly,
    required this.pinnedInPhaseCount,
  });

  final FormulaPhase phase;
  final bool pinnedOnly;
  final int pinnedInPhaseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phaseLabel = phase.displayLabel;

    if (pinnedOnly && pinnedInPhaseCount == 0) {
      return _EmptyState(
        key: ValueKey('formula_kit.${phase.analyticsValue}_empty_no_pins'),
        icon: FontAwesomeIcons.thumbtack,
        message:
            'No pinned $phaseLabel formulas yet. Tap the thumbtack on any '
            '$phaseLabel formula to pin it for plan generation.',
      );
    }
    if (pinnedOnly && pinnedInPhaseCount > 0) {
      return _EmptyState(
        key: ValueKey(
          'formula_kit.${phase.analyticsValue}_empty_pins_filtered',
        ),
        icon: FontAwesomeIcons.filter,
        message:
            'You have $pinnedInPhaseCount pinned $phaseLabel '
            '${pinnedInPhaseCount == 1 ? 'formula' : 'formulas'}, but none '
            'match these filters.',
        action: TextButton(
          key: ValueKey(
            'formula_kit.${phase.analyticsValue}_empty_clear_filters',
          ),
          onPressed: () {
            final controller =
                ref.read(formulaLibraryControllerProvider.notifier);
            controller.clearPhaseChipFilters();
            controller.clearMoreFilters();
          },
          child: const Text('Clear filters'),
        ),
      );
    }
    return _EmptyState(
      key: ValueKey('formula_kit.${phase.analyticsValue}_empty_state'),
      icon: FontAwesomeIcons.filter,
      message: 'No $phaseLabel formulas match your filters.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.message,
    this.icon = FontAwesomeIcons.filter,
    this.action,
  });

  final String message;
  // Typed as FaIconData (not IconData) because FaIcon's `icon` param rejects
  // plain IconData. We don't need to mix in Material icons here.
  final FaIconData icon;
  final Widget? action;

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
              icon,
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
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// AppBar trailing action that toggles "pinned only" view. Mirrors the
/// thumbtack glyph on cards: orange when active, muted when not. Tapping
/// shows only formulas the user has pinned (still scoped to phase + other
/// active filters per Q3a — pinned-only stacks, doesn't override).
class _PinnedOnlyButton extends ConsumerWidget {
  const _PinnedOnlyButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = ref
        .watch(formulaLibraryControllerProvider)
        .maybeWhen(
          data: (s) => s.filter.pinnedOnly,
          orElse: () => false,
        );
    final pinnedCount = ref.watch(formulaPinControllerProvider).maybeWhen(
          data: (s) => s.pinnedTemplateIds.length,
          orElse: () => 0,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Material(
        color: isActive
            ? AppColors.orange.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadius.circularRadius,
        child: InkWell(
          key: const ValueKey('formula_kit.pinned_only_button'),
          borderRadius: AppRadius.circularRadius,
          onTap: () => ref
              .read(formulaLibraryControllerProvider.notifier)
              .togglePinnedOnly(pinnedCount: pinnedCount),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.thumbtack,
                size: 16,
                color: isActive ? AppColors.orange : scheme.onSurface,
              ),
            ),
          ),
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
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.sliders,
                  size: 16,
                  color: hasActive ? AppColors.orange : scheme.onSurface,
                ),
                if (hasActive)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      key: const ValueKey('formula_kit.more_filters_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$activeCount',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blackberry,
                        ),
                      ),
                    ),
                  ),
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
