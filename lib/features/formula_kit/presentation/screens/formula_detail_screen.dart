import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/adaptive/adaptive.dart';

import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../auth/data/user_repository.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../application/formula_library_controller.dart';
import '../../application/personal_formulas_controller.dart';
import '../../domain/formula_macros.dart';
import '../../domain/formula_phase.dart';
import '../../domain/formula_pin.dart' show TemplateKind;
import '../../domain/formula_view.dart';
import '../../domain/personal_formula.dart';
import '../widgets/pin_toggle.dart';

/// Read-only detail view for a system formula (PR 1).
///
/// Re-uses `formulaLibraryControllerProvider` state to look up the formula
/// by `id` + `phase` — avoids spinning up a second fetch since the user
/// arrived here from the library list.
///
/// Edit / personalize / favorite affordances land in PR 2-5.
class FormulaDetailScreen extends ConsumerStatefulWidget {
  const FormulaDetailScreen({super.key, required this.id, required this.phase});

  final String id;
  final FormulaPhase phase;

  @override
  ConsumerState<FormulaDetailScreen> createState() =>
      _FormulaDetailScreenState();
}

class _FormulaDetailScreenState extends ConsumerState<FormulaDetailScreen> {
  bool _trackedView = false;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(formulaLibraryControllerProvider);

    // Only fire the analytics event once, and only when we have confirmed data
    // with a matching formula. Guard against the not-found path to avoid
    // logging a formula_detail_viewed event for a non-existent template.
    if (!_trackedView) {
      asyncState.whenData((state) {
        final found = switch (widget.phase) {
          FormulaPhase.before =>
            state.beforeFormulas.cast<BeforeFormulaView?>().firstWhere(
              (f) => f?.id == widget.id,
              orElse: () => null,
            ),
          FormulaPhase.during =>
            state.duringFormulas.cast<DuringFormulaView?>().firstWhere(
              (f) => f?.id == widget.id,
              orElse: () => null,
            ),
          FormulaPhase.after =>
            state.afterFormulas.cast<AfterFormulaView?>().firstWhere(
              (f) => f?.id == widget.id,
              orElse: () => null,
            ),
        };
        if (found != null) {
          _trackedView = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref
                .read(formulaLibraryControllerProvider.notifier)
                .trackDetailViewed(
                  templateId: widget.id,
                  phase: widget.phase,
                  isPersonal: false,
                );
          });
        }
      });
    }

    return AdaptivePageScaffold(
      key: ValueKey(
        'formula_kit.detail_screen.${widget.phase.name}.${widget.id}',
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, asyncState),
      contentWidth: AdaptiveContentWidth.standard,
      body: asyncState.when(
        loading: () => const Center(
          key: ValueKey('formula_kit.detail_loading'),
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (e, _) => _ErrorView(message: e.toString()),
        data: (state) {
          switch (widget.phase) {
            case FormulaPhase.before:
              final formula = state.beforeFormulas
                  .cast<BeforeFormulaView?>()
                  .firstWhere((f) => f?.id == widget.id, orElse: () => null);
              if (formula == null) return const _NotFoundView();
              return _BeforeDetailBody(formula: formula);
            case FormulaPhase.during:
              final formula = state.duringFormulas
                  .cast<DuringFormulaView?>()
                  .firstWhere((f) => f?.id == widget.id, orElse: () => null);
              if (formula == null) return const _NotFoundView();
              return _DuringDetailBody(formula: formula);
            case FormulaPhase.after:
              final formula = state.afterFormulas
                  .cast<AfterFormulaView?>()
                  .firstWhere((f) => f?.id == widget.id, orElse: () => null);
              if (formula == null) return const _NotFoundView();
              return _AfterDetailBody(formula: formula);
          }
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AsyncValue<FormulaLibraryState> asyncState,
  ) {
    String title = 'Formula';
    BeforeFormulaView? beforeFormula;
    DuringFormulaView? duringFormula;
    AfterFormulaView? afterFormula;
    asyncState.whenData((state) {
      switch (widget.phase) {
        case FormulaPhase.before:
          beforeFormula = state.beforeFormulas
              .cast<BeforeFormulaView?>()
              .firstWhere((f) => f?.id == widget.id, orElse: () => null);
          title = beforeFormula != null ? beforeFormula!.name : 'Not found';
        case FormulaPhase.during:
          duringFormula = state.duringFormulas
              .cast<DuringFormulaView?>()
              .firstWhere((f) => f?.id == widget.id, orElse: () => null);
          title = duringFormula != null ? duringFormula!.formula : 'Not found';
        case FormulaPhase.after:
          afterFormula = state.afterFormulas
              .cast<AfterFormulaView?>()
              .firstWhere((f) => f?.id == widget.id, orElse: () => null);
          title = afterFormula != null ? afterFormula!.name : 'Not found';
      }
    });

    // V1: only food templates are pinnable. Before drink/electrolyte cards
    // hide the toggle; During and After templates are all food by design.
    Widget? pinAction;
    if (beforeFormula != null && beforeFormula!.isPinnable) {
      pinAction = PinToggleBefore(
        key: ValueKey('formula_kit.detail_pin_${beforeFormula!.id}'),
        formula: beforeFormula!,
        source: 'detail',
      );
    } else if (duringFormula != null) {
      pinAction = PinToggleDuring(
        key: ValueKey('formula_kit.detail_pin_${duringFormula!.id}'),
        formula: duringFormula!,
        source: 'detail',
      );
    } else if (afterFormula != null) {
      pinAction = PinToggleAfter(
        key: ValueKey('formula_kit.detail_pin_${afterFormula!.id}'),
        formula: afterFormula!,
        source: 'detail',
      );
    }

    final hasFormula =
        beforeFormula != null || duringFormula != null || afterFormula != null;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(),
      // FittedBox scales the title down instead of ellipsizing long formula
      // names (item 17, 2026-07-04) — mirrors the pattern used by
      // fuel_timeline_day_header.dart.
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          key: const ValueKey('formula_kit.detail_title'),
          softWrap: false,
          maxLines: 1,
          style: AppTextStyles.sectionTitle.copyWith(
            fontSize: 17,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      actions: [
        if (hasFormula)
          TextButton(
            key: const ValueKey('formula_kit.make_this_mine'),
            onPressed: () => _makeThisMine(
              context,
              ref,
              before: beforeFormula,
              during: duringFormula,
              after: afterFormula,
            ),
            child: const Text('Make this mine'),
          ),
        if (pinAction != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: pinAction,
          ),
      ],
    );
  }

  /// Fork a system formula into an editable personal formula. Copies the
  /// source's component rows (each with snapshotted per-serving macros) plus
  /// name / phase / scope / source reference, then opens the editor where the
  /// user adjusts/swaps/deletes those rows.
  Future<void> _makeThisMine(
    BuildContext context,
    WidgetRef ref, {
    BeforeFormulaView? before,
    DuringFormulaView? during,
    AfterFormulaView? after,
  }) async {
    final library = ref.read(formulaLibraryControllerProvider.notifier);
    final tappedId = before?.id ?? during?.id ?? after?.id ?? '';
    final tappedPhase = before != null
        ? FormulaPhase.before
        : during != null
        ? FormulaPhase.during
        : FormulaPhase.after;
    await library.trackForkStarted(
      sourceTemplateId: tappedId,
      phase: tappedPhase,
    );

    final userRepo = await ref.read(userRepositoryProvider.future);
    final userId = (await userRepo.getCurrentUser())?.id;
    if (userId == null) {
      await library.trackForkFailed(
        sourceTemplateId: tappedId,
        phase: tappedPhase,
        reason: 'no_user',
      );
      return;
    }
    final now = DateTime.now();

    // Resolve phase + source + scope from whichever view was supplied.
    final FormulaPhase phase;
    final String sourceId;
    final TemplateKind sourceKind;
    final String name;
    String? subPhase;
    String? digestSpeed;
    List<String>? activities;
    List<String>? durations;
    String? travelFriendliness;

    if (before != null) {
      phase = FormulaPhase.before;
      sourceId = before.id;
      sourceKind = TemplateKind.preSystem;
      name = before.name;
      subPhase = before.subPhase?.storageValue;
      digestSpeed = before.digestionSpeed.toLowerCase().isEmpty
          ? null
          : before.digestionSpeed.toLowerCase();
    } else if (during != null) {
      phase = FormulaPhase.during;
      sourceId = during.id;
      sourceKind = TemplateKind.duringSystem;
      name = during.name;
      activities = during.activityTypes;
      durations = during.durationBrackets;
    } else if (after != null) {
      phase = FormulaPhase.after;
      sourceId = after.id;
      sourceKind = TemplateKind.postSystem;
      name = after.name;
      activities = after.activityTypes;
      travelFriendliness = after.travelFriendliness;
    } else {
      await library.trackForkFailed(
        sourceTemplateId: tappedId,
        phase: tappedPhase,
        reason: 'no_source_view',
      );
      return;
    }

    // Copy the source formula's component rows (with per-serving macros).
    final components = await ref
        .read(formulaLibraryControllerProvider.notifier)
        .componentsForFork(sourceId, phase);
    final totals = FormulaMacros.totalsFor(components);

    final draft = PersonalFormula(
      id: '',
      userId: userId,
      name: name,
      provenance: FormulaProvenance.forkedFormula,
      phase: phase,
      sourceTemplateId: sourceId,
      sourceTemplateKind: sourceKind,
      subPhase: subPhase,
      digestSpeed: digestSpeed,
      activities: activities,
      durations: durations,
      travelFriendliness: travelFriendliness,
      components: components,
      totalCarbsG: totals.carbsG,
      totalProteinG: totals.proteinG,
      totalFatG: totals.fatG,
      totalSodiumMg: totals.sodiumMg,
      totalFluidsMl: totals.fluidsMl,
      totalCalories: totals.calories,
      createdAt: now,
      updatedAt: now,
    );

    final saved = await ref
        .read(personalFormulasControllerProvider.notifier)
        .createFormula(draft);
    if (saved == null) {
      await library.trackForkFailed(
        sourceTemplateId: tappedId,
        phase: tappedPhase,
        reason: 'save_failed',
      );
      return;
    }
    if (!context.mounted) return;
    MealvanaSnackbar.showSuccess(context, 'Added to Your Formulas');
    // Open the editor directly (personal/:id IS the editor). Use
    // pushReplacement (not push) so the read-only system-formula detail
    // screen is swapped out of the stack rather than left underneath —
    // otherwise the editor's Save button pops back onto the detail screen
    // instead of the formula library list (item 10, 2026-07-04).
    context.pushReplacement(
      '/settings/food-preferences/formula-library/personal/${saved.id}',
    );
  }
}

// ─── Before body ──────────────────────────────────────────────────────────

class _BeforeDetailBody extends StatelessWidget {
  const _BeforeDetailBody({required this.formula});

  final BeforeFormulaView formula;

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
              _InfoPill(label: formula.timingWindow, color: AppColors.orange),
              if (formula.digestionSpeed.isNotEmpty)
                _InfoPill(
                  label: '${formula.digestionSpeed} digest',
                  color: AppColors.electrolyte,
                ),
              if (formula.subPhase != null)
                _InfoPill(
                  label: formula.subPhase!.displayLabel,
                  color: AppColors.electrolyte,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(
            calories: formula.totalCalories,
            carbs: formula.totalCarbsG,
            protein: formula.totalProteinG,
            fat: formula.totalFatG,
            sodium: formula.totalSodiumMg,
            fluid: formula.totalFluidMl,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          if (formula.componentDisplayStrings.isEmpty)
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No components listed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (
              var i = 0;
              i < formula.componentDisplayStrings.length;
              i++
            ) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ComponentRow(label: formula.componentDisplayStrings[i]),
            ],
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
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
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── During body ──────────────────────────────────────────────────────────

class _DuringDetailBody extends StatelessWidget {
  const _DuringDetailBody({required this.formula});

  final DuringFormulaView formula;

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
              if (formula.foodForm.isNotEmpty)
                _InfoPill(
                  label: formula.foodForm,
                  color: AppColors.electrolyte,
                ),
              if (formula.primaryToSecondaryRatio != null)
                _InfoPill(
                  label: 'Ratio ${formula.primaryToSecondaryRatio}',
                  color: AppColors.orange,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (formula.activityTypes.isNotEmpty) ...[
            _SectionLabel(text: 'Activities'),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in formula.activityTypes)
                  _Tag(label: _humanActivity(a)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formula.durationBrackets.isNotEmpty)
                Expanded(
                  child: _LabeledList(
                    label: 'Duration',
                    items: formula.durationBrackets,
                  ),
                ),
              if (formula.gutTrainingLevels.isNotEmpty)
                Expanded(
                  child: _LabeledList(
                    label: 'Gut training',
                    items: formula.gutTrainingLevels
                        .map((g) => '${g[0].toUpperCase()}${g.substring(1)}')
                        .toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          BaseCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formula.componentFoodNames.isEmpty
                        ? formula.formula
                        : formula.componentFoodNames.join(', '),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.boltLightning,
                          size: 12,
                          color: AppColors.orange,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Macros scale to your hourly carb target',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
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
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }

  String _humanActivity(String raw) {
    return switch (raw) {
      'triathlon_bike' => 'Tri — Bike',
      'triathlon_run' => 'Tri — Run',
      'triathlon_transition' => 'Tri — Transition',
      _ => raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}',
    };
  }
}

// ─── After body ───────────────────────────────────────────────────────────

/// Read-only detail body for an After-phase formula. Unlike Before/During,
/// the After phase has no body-size scaling target — a template represents
/// a single canonical portion. We surface the portion description, Notion
/// taxonomy chips (travel / prep / flavor / protein anchor / carb:protein
/// ratio), the formula's component foods, and dietary tags. No macros card
/// (post_workout_templates does not store macros directly in V1) and no
/// quantity stepper.
class _AfterDetailBody extends StatelessWidget {
  const _AfterDetailBody({required this.formula});

  final AfterFormulaView formula;

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
              if (formula.travelFriendliness != null &&
                  formula.travelFriendliness!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.travelFriendliness!),
                  color: AppColors.electrolyte,
                ),
              if (formula.prepEffort != null && formula.prepEffort!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.prepEffort!),
                  color: AppColors.electrolyte,
                ),
              if (formula.flavorProfile != null &&
                  formula.flavorProfile!.isNotEmpty)
                _InfoPill(
                  label: _humanize(formula.flavorProfile!),
                  color: AppColors.electrolyte,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _MacrosCard(
            calories: formula.totalCalories,
            carbs: formula.totalCarbsG,
            protein: formula.totalProteinG,
            fat: formula.totalFatG,
            sodium: formula.totalSodiumMg,
            fluid: formula.totalFluidMl,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel(text: 'Components'),
          const SizedBox(height: AppSpacing.xs),
          if (formula.componentDisplayStrings.isEmpty)
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  formula.formula.isEmpty
                      ? 'No components listed.'
                      : formula.formula,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (
              var i = 0;
              i < formula.componentDisplayStrings.length;
              i++
            ) ...[
              if (i > 0) const SizedBox(height: AppSpacing.xs),
              _ComponentRow(label: formula.componentDisplayStrings[i]),
            ],
          if (formula.notes != null && formula.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionLabel(text: 'Notes'),
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
          if (formula.allergens.isNotEmpty ||
              formula.excludedDiets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DietTags(
              allergens: formula.allergens,
              excludedDiets: formula.excludedDiets,
            ),
          ],
        ],
      ),
    );
  }

  String _humanize(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .split('_')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }
}

// ─── Shared bits ──────────────────────────────────────────────────────────

/// A single component row used in the Before-formula detail "Components"
/// section. Renders as its own card with an orange utensil-icon badge on the
/// left and the pre-formatted display string (e.g. `"1 cup Blueberries"`).
class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const FaIcon(
                FontAwesomeIcons.utensils,
                size: 14,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.bodyMedium.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

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
        color: color.withValues(alpha: 0.18),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _LabeledList extends StatelessWidget {
  const _LabeledList({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: label),
        const SizedBox(height: AppSpacing.xs),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              i,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

class _MacrosCard extends ConsumerWidget {
  const _MacrosCard({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sodium,
    required this.fluid,
  });

  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final double sodium;
  final double fluid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _Macro(label: 'Cal', value: '$calories'),
                ),
                Expanded(
                  child: _Macro(label: 'Carbs', value: '${carbs.round()}g'),
                ),
                Expanded(
                  child: _Macro(label: 'Protein', value: '${protein.round()}g'),
                ),
                Expanded(
                  child: _Macro(label: 'Fat', value: '${fat.round()}g'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Macro(label: 'Sodium', value: '${sodium.round()}mg'),
                ),
                Expanded(
                  child: _Macro(
                    label: 'Fluid',
                    value: UnitFormatter.formatFluids(
                      fluid,
                      useMetric: useMetric,
                    ),
                  ),
                ),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DietTags extends StatelessWidget {
  const _DietTags({required this.allergens, required this.excludedDiets});

  final List<String> allergens;
  final List<String> excludedDiets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Dietary'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final a in allergens) _Tag(label: 'Contains $a'),
            for (final d in excludedDiets)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dragonfruit.withValues(alpha: 0.12),
                  borderRadius: AppRadius.circularRadius,
                ),
                child: Text(
                  'Not $d',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dragonfruit,
                  ),
                ),
              ),
          ],
        ),
        if (allergens.isEmpty && excludedDiets.isEmpty)
          Text(
            'No restrictions noted.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('formula_kit.detail_not_found'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.circleQuestion,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Formula not found.', style: AppTextStyles.subtitle),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('formula_kit.detail_error'),
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
              'Could not load formula',
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
