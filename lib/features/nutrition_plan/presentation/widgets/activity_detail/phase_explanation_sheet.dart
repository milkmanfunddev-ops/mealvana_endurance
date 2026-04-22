import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../auth/domain/user_preferences.dart';
import '../../../../settings/presentation/providers/settings_controller.dart';
import '../../../application/macro_explanation_service.dart';
import '../../../application/resolved_during_target_resolver.dart';
import '../../../domain/nutrient_transparency_data.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/macro_targets.dart';
import '../../../domain/nutrition_target_overrides.dart';
import '../../../domain/resolved_during_target.dart';
import '../../../../../shared/domain/activity_type.dart';
import 'nutrient_calculation_section.dart';
import 'nutrient_full_story_section.dart';
import 'nutrient_tldr_section.dart';
import 'transparency_video_section.dart';

// [Scenario] is now the public enum defined in nutrient_transparency_data.dart.

/// Bottom sheet that explains how nutrition targets were calculated for a given
/// phase.
///
/// All macros (Carbs, Fluids, Sodium, Protein) are rendered via the same
/// `_NutrientTransparencyCard` private widget. A tab bar appears above the
/// cards for during-workout phases when multiple scenarios apply.
///
/// Pass [onRegenerate] when the sheet is opened from an activity-detail context
/// so that inline sweat-rate / sodium-concentration saves trigger a plan
/// refresh. The callback is called after the profile save completes.
class PhaseExplanationSheet extends ConsumerStatefulWidget {
  const PhaseExplanationSheet({
    super.key,
    required this.phase,
    required this.macroTargets,
    required this.bodyWeightKg,
    this.sportLabel,
    this.useImperial = false,
    this.foods,
    this.brickSegment,
    this.isBrick = false,
    this.onRegenerate,
  });

  final ExplanationPhase phase;
  final MacroTargets macroTargets;
  final double bodyWeightKg;
  final String? sportLabel;
  final bool useImperial;
  final List<FoodItemData>? foods;
  final BrickSegmentMacroTarget? brickSegment;
  final bool isBrick;

  /// Called after a profile save (sweat rate / sodium concentration) so the
  /// caller can trigger macro regeneration.
  final VoidCallback? onRegenerate;

  /// Show the explanation sheet as a modal bottom sheet.
  static void show(
    BuildContext context, {
    required ExplanationPhase phase,
    required MacroTargets macroTargets,
    required double bodyWeightKg,
    String? sportLabel,
    bool useImperial = false,
    List<FoodItemData>? foods,
    BrickSegmentMacroTarget? brickSegment,
    bool isBrick = false,
    VoidCallback? onRegenerate,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PhaseExplanationSheet(
        phase: phase,
        macroTargets: macroTargets,
        bodyWeightKg: bodyWeightKg,
        sportLabel: sportLabel,
        useImperial: useImperial,
        foods: foods,
        brickSegment: brickSegment,
        isBrick: isBrick,
        onRegenerate: onRegenerate,
      ),
    );
  }

  @override
  ConsumerState<PhaseExplanationSheet> createState() =>
      _PhaseExplanationSheetState();
}

class _PhaseExplanationSheetState
    extends ConsumerState<PhaseExplanationSheet> {
  final _service = const MacroExplanationService();

  /// Which scenario tab is active (during-workout only; null otherwise).
  Scenario? _activeScenario;

  @override
  void initState() {
    super.initState();
    final scenarios = _deriveScenariosForWorkout();
    if (scenarios.isNotEmpty) _activeScenario = scenarios.first;
  }

  // ---------------------------------------------------------------------------
  // Scenario derivation
  // ---------------------------------------------------------------------------

  /// Derives which scenario tabs to show for the current workout shape.
  ///
  /// The returned list is the *intersection* of:
  /// 1. Scenarios that are structurally relevant for this workout shape.
  /// 2. Scenarios present in the fluid/sodium transparency maps (i.e. have content).
  ///
  /// Rules:
  /// - Only meaningful during the `during` / `transition` phase.
  /// - Single sport (non-brick): [Scenario.singleSport]; add [Scenario.knownRate]
  ///   if isTested; add [Scenario.shortWorkout] when the gate applies.
  /// - Brick: [Scenario.multiSegment]; add [Scenario.t1t2] when transitions exist;
  ///   add [Scenario.redistribution] when any safety_flags mention redistribution;
  ///   add [Scenario.knownRate] if isTested.
  /// - Swim segment (inside brick): always returns empty — rendered as zero-state.
  List<Scenario> _deriveScenariosForWorkout({
    Set<Scenario>? availableInMaps,
  }) {
    if (widget.phase != ExplanationPhase.during &&
        widget.phase != ExplanationPhase.transition1 &&
        widget.phase != ExplanationPhase.transition2) {
      return [];
    }

    // Swim segment has no scenarios
    final brickSport = widget.brickSegment?.sport ?? '';
    if (brickSport.contains('swim')) return [];

    final during = widget.macroTargets.duringRun;
    final isTested = widget.brickSegment?.isTested ?? during.isTested;
    final durationMin = widget.macroTargets.metrics.durationMin;
    final tempC = during.tempC;
    final isShortGate = durationMin < 60 &&
        (tempC == null || tempC < 30);

    List<Scenario> scenarios;

    if (widget.isBrick) {
      scenarios = [Scenario.multiSegment];
      final transitions =
          widget.macroTargets.brickPhaseTargets?.transitions ?? [];
      if (transitions.isNotEmpty) scenarios.add(Scenario.t1t2);
      final hasRedistribution = [
        ...during.safetyFlags,
        ...(widget.brickSegment?.safetyFlags ?? []),
      ].any((f) => f.toLowerCase().contains('redistri'));
      if (hasRedistribution) scenarios.add(Scenario.redistribution);
      if (isTested) scenarios.add(Scenario.knownRate);
    } else {
      scenarios = [Scenario.singleSport];
      if (isShortGate) scenarios.add(Scenario.shortWorkout);
      if (isTested) scenarios.add(Scenario.knownRate);
    }

    // Intersect with what actually has content in the service maps
    if (availableInMaps != null) {
      scenarios = scenarios.where(availableInMaps.contains).toList();
    }

    return scenarios;
  }

  String _scenarioLabel(Scenario s) {
    switch (s) {
      case Scenario.singleSport:
        return 'Single Sport';
      case Scenario.knownRate:
        return 'Known Rate';
      case Scenario.shortWorkout:
        return 'Short Workout';
      case Scenario.multiSegment:
        return 'Multi-Segment';
      case Scenario.redistribution:
        return 'Redistribution';
      case Scenario.t1t2:
        return 'T1 / T2';
    }
  }

  // ---------------------------------------------------------------------------
  // Carb transparency helper (unchanged from Phase 4)
  // ---------------------------------------------------------------------------

  NutrientTransparencyData? _getCarbTransparencyData() {
    final settingsState = ref.read(settingsControllerProvider).value;
    final fallbackGutTraining =
        settingsState?.gutTrainingLevel ?? GutTraining.moderate;
    final snapshotGutMultiplier =
        widget.brickSegment?.gutMultiplier ??
        widget.macroTargets.duringRun.gutMultiplier;
    final gutMultiplier =
        snapshotGutMultiplier ??
        switch (fallbackGutTraining) {
          GutTraining.low => 0.7,
          GutTraining.moderate => 1.0,
          GutTraining.high => 1.2,
        };
    final gutTrainingLabel =
        _gutTrainingLabelFromMultiplier(snapshotGutMultiplier) ??
        fallbackGutTraining.name;
    final overrides = settingsState?.nutritionTargetOverrides;
    final sport =
        widget.brickSegment?.sport ??
        widget.sportLabel?.toLowerCase() ??
        'running';
    final resolvedDuringTarget = _resolveDuringTarget(
      overrides: overrides,
      sportLabel: sport,
    );

    return _service.getCarbTransparencyData(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      gutTrainingLabel: gutTrainingLabel,
      gutMultiplier: gutMultiplier,
      personalCarbTargetGPerH: resolvedDuringTarget?.settingsOverrideRateGPerH,
      personalTargetSport: sport,
      sportLabel: widget.sportLabel,
      brickSegment: widget.brickSegment,
      isBrick: widget.isBrick,
      resolvedDuringTarget: resolvedDuringTarget,
    );
  }

  ResolvedDuringTarget? _resolveDuringTarget({
    required NutritionTargetOverrides? overrides,
    required String sportLabel,
  }) {
    if (widget.phase != ExplanationPhase.during) return null;

    if (widget.isBrick && widget.brickSegment != null) {
      return ResolvedDuringTargetResolver.resolveForBrickSegment(
        macroTargets: widget.macroTargets,
        segment: widget.brickSegment!,
        settingsOverrides: overrides,
      );
    }

    return ResolvedDuringTargetResolver.resolveForSingleSport(
      macroTargets: widget.macroTargets,
      sport: _sportFromLabel(sportLabel),
      settingsOverrides: overrides,
    );
  }

  ActivityType _sportFromLabel(String value) {
    final sport = value.toLowerCase();
    if (sport.contains('run')) return ActivityType.running;
    if (sport.contains('cycl') || sport.contains('bike')) {
      return ActivityType.cycling;
    }
    if (sport.contains('swim')) return ActivityType.swimming;
    return ActivityType.running;
  }

  String? _gutTrainingLabelFromMultiplier(double? value) {
    if (value == null) return null;
    if ((value - 0.7).abs() <= 0.05) return GutTraining.low.name;
    if ((value - 1.0).abs() <= 0.05) return GutTraining.moderate.name;
    if ((value - 1.2).abs() <= 0.05) return GutTraining.high.name;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Actuals computation
  // ---------------------------------------------------------------------------

  Map<String, int>? _computeActuals() {
    final foods = widget.foods;
    if (foods == null || foods.isEmpty) return null;

    int carbs = 0;
    int protein = 0;
    int sodium = 0;
    int fluids = 0;

    for (final food in foods) {
      final info = food.nutritionalInfo;
      if (info != null) {
        carbs += info.carbs ?? 0;
        protein += info.protein ?? 0;
        sodium += info.sodium ?? 0;
        fluids += (info.fluids ?? 0).round();
      }
    }

    return {
      'carbs': carbs,
      'protein': protein,
      'sodium': sodium,
      'fluids': fluids,
    };
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch settings for live updates after inline edits
    ref.watch(settingsControllerProvider);

    final title = _service.getSheetTitle(widget.phase, widget.sportLabel);
    final actuals = _computeActuals();

    // Collect all transparency data maps for this phase
    final carbTransparency = _getCarbTransparencyData();
    final fluidMap = _service.getFluidTransparencyData(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
      brickSegment: widget.brickSegment,
      isBrick: widget.isBrick,
    );
    final sodiumMap = _service.getSodiumTransparencyData(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      brickSegment: widget.brickSegment,
      isBrick: widget.isBrick,
    );

    // The swim zero-state is returned as null from the maps; render it directly
    final brickSport = widget.brickSegment?.sport ?? '';
    final isSwimSegment = brickSport.contains('swim');
    final swimFluid = isSwimSegment
        ? _service.getSwimFluidTransparency()
        : null;
    final swimSodium = isSwimSegment
        ? _service.getSwimSodiumTransparency()
        : null;

    // Derive available scenarios as the union of both maps' keys
    final allAvailableKeys = <Scenario>{
      ...?fluidMap?.keys,
      ...?sodiumMap?.keys,
    };
    final scenarios = _deriveScenariosForWorkout(
      availableInMaps: allAvailableKeys.isNotEmpty ? allAvailableKeys : null,
    );

    // Resolve active scenario (reset to first if current one is not in the list)
    final effectiveActiveScenario =
        scenarios.contains(_activeScenario) ? _activeScenario : scenarios.firstOrNull;

    // Pick per-scenario content driven by the active tab.
    NutrientTransparencyData? pickFromMap(
        Map<Scenario, NutrientTransparencyData>? map) {
      if (map == null) return null;
      if (effectiveActiveScenario != null &&
          map.containsKey(effectiveActiveScenario)) {
        return map[effectiveActiveScenario];
      }
      return map.values.firstOrNull;
    }

    final fluidTransparency =
        isSwimSegment ? swimFluid : pickFromMap(fluidMap);
    final sodiumTransparency =
        isSwimSegment ? swimSodium : pickFromMap(sodiumMap);

    // Legacy explanations for any remaining macros (After phase: Protein; Before: labels)
    final legacyExplanations = _service.getExplanations(
      phase: widget.phase,
      macroTargets: widget.macroTargets,
      bodyWeightKg: widget.bodyWeightKg,
      useImperial: widget.useImperial,
      actuals: actuals,
      brickSegment: widget.brickSegment,
    );

    final showTabBar = scenarios.length > 1;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Scenario tab bar (during-workout with >1 scenario)
            if (showTabBar) ...[
              _ScenarioTabBar(
                scenarios: scenarios,
                active: effectiveActiveScenario ?? scenarios.first,
                onTap: (s) => setState(() => _activeScenario = s),
              ),
              const SizedBox(height: AppSpacing.md),
            ] else if (scenarios.length == 1) ...[
              // Single scenario — render as static label
              _ScenarioStaticLabel(label: _scenarioLabel(scenarios.first)),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carbs card — uses new transparency pipeline
                    if (carbTransparency != null)
                      _NutrientTransparencyCard(
                        label: 'Carbohydrates',
                        transparency: carbTransparency,
                        actualValue: actuals != null
                            ? '${actuals['carbs'] ?? 0}'
                            : null,
                        unit: 'g',
                        onSettingsChanged: () => setState(() {}),
                        onRegenerate: widget.onRegenerate,
                      ),

                    // Fluids card
                    if (fluidTransparency != null)
                      _NutrientTransparencyCard(
                        label: 'Fluids',
                        transparency: fluidTransparency,
                        actualValue: actuals != null
                            ? widget.useImperial
                                ? '${((actuals['fluids'] ?? 0) * 0.033814).round()}'
                                : '${actuals['fluids'] ?? 0}'
                            : null,
                        unit: widget.useImperial ? 'oz' : 'mL',
                        onSettingsChanged: () => setState(() {}),
                        onRegenerate: widget.onRegenerate,
                      ),

                    // Sodium card
                    if (sodiumTransparency != null)
                      _NutrientTransparencyCard(
                        label: 'Sodium',
                        transparency: sodiumTransparency,
                        actualValue: actuals != null
                            ? '${actuals['sodium'] ?? 0}'
                            : null,
                        unit: 'mg',
                        onSettingsChanged: () => setState(() {}),
                        onRegenerate: widget.onRegenerate,
                      ),

                    // Remaining macros that have no transparency data yet
                    // (Protein on After phase; carbs/fluids/sodium that fell
                    //  through when carbTransparency is null)
                    for (final explanation in legacyExplanations)
                      if (_shouldShowLegacyCard(
                          explanation.macroName, carbTransparency,
                          fluidTransparency, sodiumTransparency))
                        _buildExplanationCard(context, explanation),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns true when the legacy card should be shown for a macro that was
  /// NOT already covered by a transparency card.
  bool _shouldShowLegacyCard(
    String macroName,
    NutrientTransparencyData? carbData,
    NutrientTransparencyData? fluidData,
    NutrientTransparencyData? sodiumData,
  ) {
    switch (macroName) {
      case 'Carbohydrates':
        return carbData == null;
      case 'Fluids':
        return fluidData == null;
      case 'Sodium':
        return sodiumData == null;
      default:
        // Protein, Fat, etc. always show the legacy card
        return true;
    }
  }

  Widget _buildExplanationCard(
    BuildContext context,
    MacroExplanation explanation,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              explanation.displayHeader,
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (explanation.displaySubHeader != null) ...[
              const SizedBox(height: 2),
              Text(
                explanation.displaySubHeader!,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              explanation.formulaText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                explanation.rangeRationale,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.electrolyte,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

/// Scenario tab bar shown when multiple scenarios apply.
class _ScenarioTabBar extends StatelessWidget {
  const _ScenarioTabBar({
    required this.scenarios,
    required this.active,
    required this.onTap,
  });

  final List<Scenario> scenarios;
  final Scenario active;
  final ValueChanged<Scenario> onTap;

  String _label(Scenario s) {
    switch (s) {
      case Scenario.singleSport:
        return 'Single Sport';
      case Scenario.knownRate:
        return 'Known Rate';
      case Scenario.shortWorkout:
        return 'Short Workout';
      case Scenario.multiSegment:
        return 'Multi-Segment';
      case Scenario.redistribution:
        return 'Redistribution';
      case Scenario.t1t2:
        return 'T1 / T2';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          final isActive = s == active;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onTap(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.electrolyte.withValues(alpha: 0.12)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.electrolyte.withValues(alpha: 0.35)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                child: Text(
                  _label(s),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive
                        ? AppColors.electrolyte
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.55)
                            : Colors.black.withValues(alpha: 0.55)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Static scenario label when only one scenario applies.
class _ScenarioStaticLabel extends StatelessWidget {
  const _ScenarioStaticLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Thin private widget that composes TL;DR + Full Story + Video for one
/// nutrient card. Replaces the old `_buildCarbTransparencyCard` method and
/// works for any nutrient.
class _NutrientTransparencyCard extends StatefulWidget {
  const _NutrientTransparencyCard({
    required this.label,
    required this.transparency,
    required this.unit,
    this.actualValue,
    this.onSettingsChanged,
    this.onRegenerate,
  });

  final String label;
  final NutrientTransparencyData transparency;
  final String unit;
  final String? actualValue;
  final VoidCallback? onSettingsChanged;
  final VoidCallback? onRegenerate;

  @override
  State<_NutrientTransparencyCard> createState() =>
      _NutrientTransparencyCardState();
}

class _NutrientTransparencyCardState
    extends State<_NutrientTransparencyCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.4);
    final secondaryText = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    final accentColor = widget.transparency.nutrientColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: accent bar + label + target badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    widget.label,
                    style: AppTextStyles.sectionTitle.copyWith(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                _buildTargetBadge(
                    context, dimColor, secondaryText, accentColor),
              ],
            ),
            const SizedBox(height: 14),

            // TL;DR formula (always visible)
            NutrientTldrSection(data: widget.transparency),
            const SizedBox(height: 4),

            // Calculation accordion (only if the service populated sections)
            if (widget.transparency.calculationSections.isNotEmpty)
              NutrientCalculationSection(data: widget.transparency),

            // Video accordion — always "coming soon" for now
            if (widget.transparency.videoTitle != null)
              TransparencyVideoSection(
                title: widget.transparency.videoTitle!,
                comingSoon: true,
              ),

            // Full Story accordion
            if (widget.transparency.storySections.isNotEmpty)
              NutrientFullStorySection(
                data: widget.transparency,
                onSettingsChanged: widget.onSettingsChanged,
                onEditKnownSweatRate: widget.onRegenerate,
                onEditKnownSodiumConcentration: widget.onRegenerate,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetBadge(
    BuildContext context,
    Color dimColor,
    Color secondaryText,
    Color accentColor,
  ) {
    final transparency = widget.transparency;
    final planned = widget.actualValue;
    final target = transparency.targetGrams != null
        ? transparency.targetGrams!.round().toString()
        : null;
    final unit = widget.unit;

    if (target == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (planned != null) ...[
              Text(
                '$planned$unit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'planned',
                style: TextStyle(fontSize: 11, color: dimColor),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w300,
                    color: dimColor,
                  ),
                ),
              ),
              Text(
                '$target$unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: secondaryText,
                  letterSpacing: -0.4,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'target',
                style: TextStyle(fontSize: 11, color: dimColor),
              ),
            ] else ...[
              Text(
                '$target$unit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'target',
                style: TextStyle(fontSize: 11, color: dimColor),
              ),
            ],
          ],
        ),
        if (transparency.rangeLow != null && transparency.rangeHigh != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              'Range: ${transparency.rangeLow!.round()}\u2013${transparency.rangeHigh!.round()}$unit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
            ),
          ),
      ],
    );
  }
}
