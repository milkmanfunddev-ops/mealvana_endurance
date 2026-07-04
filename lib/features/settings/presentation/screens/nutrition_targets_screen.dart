import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../providers/settings_controller.dart';
import '../widgets/during_sport_override_section.dart';
import '../widgets/nutrition_targets_help_bottom_sheet.dart';

/// Screen for configuring default nutrition target overrides.
/// Empty fields = use algorithm defaults (null).
///
/// During-workout overrides are split by sport (Run, Bike, Swim).
/// During overrides only apply to activities >= 90 minutes.
class NutritionTargetsScreen extends ConsumerStatefulWidget {
  const NutritionTargetsScreen({super.key});

  @override
  ConsumerState<NutritionTargetsScreen> createState() =>
      _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState
    extends ConsumerState<NutritionTargetsScreen> {
  static const double _highCarbWarningThresholdGPerH = 120;
  static final Uri _iocConsensusSourceUri = Uri.parse(
    'https://doi.org/10.1080/02640414.2011.585473',
  );
  static final Uri _highCarbTrialSourceUri = Uri.parse(
    'https://pubmed.ncbi.nlm.nih.gov/32403259/',
  );
  static final Uri _veryHighCarbStudySourceUri = Uri.parse(
    'https://pubmed.ncbi.nlm.nih.gov/35565896/',
  );

  final _formKey = GlobalKey<FormState>();
  bool _hasChanges = false;
  bool _isSaving = false;

  // Mirrors the user's unitSystemProvider preference for the fluid fields
  // (all other fields - carbs/protein/fat/sodium - are physiological units
  // and unit-invariant). Fluid overrides are stored canonically in mL; when
  // this is false (imperial - the app default), fields display/accept fl oz
  // and are converted back to mL on save. Kept as local state (rather than
  // watched directly in build) so already-entered values can be converted in
  // place via `ref.listen` if the preference changes elsewhere while this
  // screen is open.
  bool _useMetric = true;

  // Pre-activity controllers
  final _preCarbsController = TextEditingController();
  final _preProteinController = TextEditingController();
  final _preFatController = TextEditingController();
  final _preSodiumController = TextEditingController();
  final _preFluidController = TextEditingController();

  // During Run controllers
  final _duringRunCarbRateController = TextEditingController();
  final _duringRunSodiumRateController = TextEditingController();
  final _duringRunFluidRateController = TextEditingController();

  // During Bike controllers
  final _duringBikeCarbRateController = TextEditingController();
  final _duringBikeSodiumRateController = TextEditingController();
  final _duringBikeFluidRateController = TextEditingController();

  // During Swim controllers
  final _duringSwimCarbRateController = TextEditingController();
  final _duringSwimSodiumRateController = TextEditingController();
  final _duringSwimFluidRateController = TextEditingController();

  // Post-activity controllers
  final _postCarbsController = TextEditingController();
  final _postProteinController = TextEditingController();
  final _postSodiumController = TextEditingController();
  final _postFluidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentOverrides();
    });
  }

  void _loadCurrentOverrides() {
    final settingsState = ref.read(settingsControllerProvider).value;
    final overrides = settingsState?.nutritionTargetOverrides;
    if (overrides == null) return;

    if (mounted) {
      setState(() {
        // Pre-activity
        if (overrides.pre != null) {
          _setController(_preCarbsController, overrides.pre!.carbsG);
          _setController(_preProteinController, overrides.pre!.proteinG);
          _setController(_preFatController, overrides.pre!.fatG);
          _setController(_preSodiumController, overrides.pre!.sodiumMg);
          _setFluidController(_preFluidController, overrides.pre!.fluidMl);
        }

        // During Run (sport-specific, with legacy fallback)
        final duringRun = overrides.duringRun ?? overrides.during;
        if (duringRun != null) {
          _setController(_duringRunCarbRateController, duringRun.carbRateGPerH);
          _setController(
            _duringRunSodiumRateController,
            duringRun.sodiumRateMgPerH,
          );
          _setFluidController(
            _duringRunFluidRateController,
            duringRun.fluidRateMlPerH,
          );
        }

        // During Bike (sport-specific, with legacy fallback)
        final duringBike = overrides.duringCycling ?? overrides.during;
        if (duringBike != null) {
          _setController(
            _duringBikeCarbRateController,
            duringBike.carbRateGPerH,
          );
          _setController(
            _duringBikeSodiumRateController,
            duringBike.sodiumRateMgPerH,
          );
          _setFluidController(
            _duringBikeFluidRateController,
            duringBike.fluidRateMlPerH,
          );
        }

        // During Swim (sport-specific, with legacy fallback)
        final duringSwim = overrides.duringSwimming ?? overrides.during;
        if (duringSwim != null) {
          // Don't load carbs for swimming (carbs N/A while swimming)
          _setController(
            _duringSwimSodiumRateController,
            duringSwim.sodiumRateMgPerH,
          );
          _setFluidController(
            _duringSwimFluidRateController,
            duringSwim.fluidRateMlPerH,
          );
        }

        // Post-activity
        if (overrides.post != null) {
          _setController(_postCarbsController, overrides.post!.carbsG);
          _setController(_postProteinController, overrides.post!.proteinG);
          _setController(_postSodiumController, overrides.post!.sodiumMg);
          _setFluidController(_postFluidController, overrides.post!.fluidMl);
        }
      });
    }

    // Apply the user's unit preference to the fluid fields (all set above in
    // canonical mL). Best-effort - falls back to the mL display already set
    // if the preference can't be resolved.
    unawaited(_applyFluidUnitPreference());
  }

  Future<void> _applyFluidUnitPreference() async {
    try {
      final unitSystem = await ref.read(unitSystemProvider.future);
      final useMetric = unitSystem == UnitSystem.metric;
      if (useMetric != _useMetric && mounted) {
        setState(() {
          _convertFluidFieldsForUnitChange(toMetric: useMetric);
          _useMetric = useMetric;
        });
      }
    } catch (_) {
      // Non-fatal - default to the mL display already set.
    }
  }

  /// Converts whatever is currently entered in the fluid fields to match
  /// [toMetric], so a mid-session unit-preference change doesn't silently
  /// mismatch the displayed value against its label. Best-effort -
  /// unparsable/empty fields are left untouched.
  void _convertFluidFieldsForUnitChange({required bool toMetric}) {
    for (final controller in [
      _preFluidController,
      _duringRunFluidRateController,
      _duringBikeFluidRateController,
      _duringSwimFluidRateController,
      _postFluidController,
    ]) {
      final entered = double.tryParse(controller.text.trim());
      if (entered == null) continue;
      final converted = toMetric
          ? entered * UnitFormatter.kMlPerFlOz
          : entered * UnitFormatter.kFlOzPerMl;
      controller.text = converted == converted.roundToDouble()
          ? converted.toInt().toString()
          : converted.toStringAsFixed(1);
    }
  }

  void _setController(TextEditingController controller, double? value) {
    if (value != null) {
      // Display as integer if whole number, otherwise 1 decimal
      controller.text = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
    }
  }

  /// Same as [_setController], but for fluid fields whose canonical unit
  /// (mL) differs from the displayed unit when [_useMetric] is false
  /// (imperial - the app default) - converts to fl oz for display.
  void _setFluidController(TextEditingController controller, double? mlValue) {
    if (mlValue == null) return;
    final displayValue = _useMetric
        ? mlValue
        : mlValue * UnitFormatter.kFlOzPerMl;
    controller.text = displayValue == displayValue.roundToDouble()
        ? displayValue.toInt().toString()
        : displayValue.toStringAsFixed(1);
  }

  /// Parses a fluid field's displayed value back to the canonical mL unit
  /// used for storage.
  double? _parseFluidField(TextEditingController controller) {
    final value = _parseField(controller);
    if (value == null) return null;
    return _useMetric ? value : value * UnitFormatter.kMlPerFlOz;
  }

  @override
  void dispose() {
    _preCarbsController.dispose();
    _preProteinController.dispose();
    _preFatController.dispose();
    _preSodiumController.dispose();
    _preFluidController.dispose();
    _duringRunCarbRateController.dispose();
    _duringRunSodiumRateController.dispose();
    _duringRunFluidRateController.dispose();
    _duringBikeCarbRateController.dispose();
    _duringBikeSodiumRateController.dispose();
    _duringBikeFluidRateController.dispose();
    _duringSwimCarbRateController.dispose();
    _duringSwimSodiumRateController.dispose();
    _duringSwimFluidRateController.dispose();
    _postCarbsController.dispose();
    _postProteinController.dispose();
    _postSodiumController.dispose();
    _postFluidController.dispose();
    super.dispose();
  }

  void _markChanged() {
    setState(() => _hasChanges = true);
  }

  double? _parseField(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  bool _isHighCarbRate(TextEditingController controller) {
    final value = _parseField(controller);
    return value != null && value >= _highCarbWarningThresholdGPerH;
  }

  Future<void> _openSourceLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      MealvanaSnackbar.showWarning(context, 'Unable to open source link');
    }
  }

  Future<void> _showHighCarbRateWarningInfoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why we warn above 120 g/hr',
                      style: AppTextStyles.subtitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Most consensus guidance supports ~30-60 g/hr during endurance work, '
                      'with up to ~90 g/hr for longer events. We flag values above 120 g/hr '
                      'because this is an advanced strategy that usually needs gut training.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Evidence for 120 g/hr exists in small elite cohorts, but it is not a '
                      'universal default. Intakes like 180 g/hr are experimental and may '
                      'increase GI distress risk for many athletes.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Sources',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => _openSourceLink(_iocConsensusSourceUri),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        'IOC consensus: Carbohydrates for training and competition (2011)',
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openSourceLink(_highCarbTrialSourceUri),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        '120 g/hr trial in elite runners (Viribay et al., 2020)',
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          _openSourceLink(_veryHighCarbStudySourceUri),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text(
                        'Very high-carb + gut training study (King et al., 2022)',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDefaultsHelpSheet() {
    final settingsState = ref.read(settingsControllerProvider).value;
    NutritionTargetsHelpBottomSheet.show(context, settingsState);
  }

  DuringActivityOverrides? _parseDuringOverride({
    required TextEditingController carbController,
    required TextEditingController sodiumController,
    required TextEditingController fluidController,
  }) {
    final during = DuringActivityOverrides(
      carbRateGPerH: _parseField(carbController),
      sodiumRateMgPerH: _parseField(sodiumController),
      fluidRateMlPerH: _parseFluidField(fluidController),
    );
    return during.hasAnyOverride ? during : null;
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);

    final pre = PreActivityOverrides(
      carbsG: _parseField(_preCarbsController),
      proteinG: _parseField(_preProteinController),
      fatG: _parseField(_preFatController),
      sodiumMg: _parseField(_preSodiumController),
      fluidMl: _parseFluidField(_preFluidController),
    );

    final post = PostActivityOverrides(
      carbsG: _parseField(_postCarbsController),
      proteinG: _parseField(_postProteinController),
      sodiumMg: _parseField(_postSodiumController),
      fluidMl: _parseFluidField(_postFluidController),
    );

    var overrides = NutritionTargetOverrides(
      pre: pre.hasAnyOverride ? pre : null,
      post: post.hasAnyOverride ? post : null,
      // Sport-specific during overrides (no legacy `during` written)
      duringRun: _parseDuringOverride(
        carbController: _duringRunCarbRateController,
        sodiumController: _duringRunSodiumRateController,
        fluidController: _duringRunFluidRateController,
      ),
      duringCycling: _parseDuringOverride(
        carbController: _duringBikeCarbRateController,
        sodiumController: _duringBikeSodiumRateController,
        fluidController: _duringBikeFluidRateController,
      ),
      duringSwimming: _parseDuringOverride(
        carbController: _duringSwimCarbRateController,
        sodiumController: _duringSwimSodiumRateController,
        fluidController: _duringSwimFluidRateController,
      ),
    );

    // Clamp to guardrails
    if (overrides.hasAnyOverride) {
      overrides = NutritionTargetGuardrails.clampAll(overrides);
    }

    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .saveNutritionTargetOverrides(
            overrides.hasAnyOverride ? overrides : null,
          );

      if (!mounted) return;

      final saveState = ref.read(settingsControllerProvider);
      if (saveState.hasError) {
        setState(() => _isSaving = false);
        MealvanaSnackbar.showError(context, 'Failed to save nutrition targets');
        return;
      }

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      MealvanaSnackbar.showSuccess(context, 'Nutrition targets saved');
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        MealvanaSnackbar.showError(context, 'Failed to save nutrition targets');
      }
    }
  }

  void _resetAll() {
    setState(() {
      _preCarbsController.clear();
      _preProteinController.clear();
      _preFatController.clear();
      _preSodiumController.clear();
      _preFluidController.clear();
      _duringRunCarbRateController.clear();
      _duringRunSodiumRateController.clear();
      _duringRunFluidRateController.clear();
      _duringBikeCarbRateController.clear();
      _duringBikeSodiumRateController.clear();
      _duringBikeFluidRateController.clear();
      _duringSwimCarbRateController.clear();
      _duringSwimSodiumRateController.clear();
      _duringSwimFluidRateController.clear();
      _postCarbsController.clear();
      _postProteinController.clear();
      _postSodiumController.clear();
      _postFluidController.clear();
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to unit-preference changes made elsewhere (e.g. another settings
    // screen) while this screen is mounted - convert the displayed fluid
    // values in place so they never mismatch their unit label.
    ref.listen<AsyncValue<UnitSystem>>(unitSystemProvider, (previous, next) {
      final newUseMetric = next.value == UnitSystem.metric;
      if (newUseMetric != _useMetric) {
        setState(() {
          _convertFluidFieldsForUnitChange(toMetric: newUseMetric);
          _useMetric = newUseMetric;
        });
      }
    });

    final showRunHighCarbWarning = _isHighCarbRate(
      _duringRunCarbRateController,
    );
    final showBikeHighCarbWarning = _isHighCarbRate(
      _duringBikeCarbRateController,
    );
    final fluidUnitLabel = UnitFormatter.fluidUnitLabel(
      useMetric: _useMetric,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const CustomAppBarBackButton(
          key: ValueKey('nutrition_targets.back_button'),
        ),
        title: Text(
          key: const ValueKey('nutrition_targets.title'),
          'Nutrition Targets',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            key: const ValueKey('nutrition_targets.help_button'),
            onPressed: _showDefaultsHelpSheet,
            icon: Icon(
              Icons.help_outline_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'How Auto defaults are calculated',
          ),
        ],
      ),
      body: ContentArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Info banner
              BaseCard(
                key: const ValueKey('nutrition_targets.info_card'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.electrolyte,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Set your preferred macro targets. Empty fields use algorithm defaults.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showDefaultsHelpSheet,
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'How Auto defaults are calculated',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Pre-Activity section
              _buildSectionCard(
                cardKey: const ValueKey('nutrition_targets.pre_section'),
                title: 'Pre-Activity',
                children: [
                  _buildField(
                    'Carbs (g)',
                    _preCarbsController,
                    fieldKey: const ValueKey(
                      'nutrition_targets.pre_carbs_field',
                    ),
                  ),
                  _buildField(
                    'Protein (g)',
                    _preProteinController,
                    fieldKey: const ValueKey(
                      'nutrition_targets.pre_protein_field',
                    ),
                  ),
                  _buildField(
                    'Fat (g)',
                    _preFatController,
                    fieldKey: const ValueKey('nutrition_targets.pre_fat_field'),
                  ),
                  _buildField(
                    'Sodium (mg)',
                    _preSodiumController,
                    fieldKey: const ValueKey(
                      'nutrition_targets.pre_sodium_field',
                    ),
                  ),
                  _buildField(
                    'Fluids ($fluidUnitLabel)',
                    _preFluidController,
                    fieldKey: const ValueKey(
                      'nutrition_targets.pre_fluids_field',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 90-minute note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  'During-workout targets only apply to activities 90 minutes or longer.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // During Run section
              DuringSportOverrideSection(
                key: const ValueKey('nutrition_targets.during_run_section'),
                sportLabel: 'Run',
                sportIcon: Icons.directions_run,
                carbController: _duringRunCarbRateController,
                sodiumController: _duringRunSodiumRateController,
                fluidController: _duringRunFluidRateController,
                useMetric: _useMetric,
                showHighCarbRateWarning: showRunHighCarbWarning,
                highCarbRateWarningThreshold: _highCarbWarningThresholdGPerH,
                onHighCarbRateWarningInfoTap: _showHighCarbRateWarningInfoSheet,
                onChanged: _markChanged,
              ),

              const SizedBox(height: AppSpacing.sm),

              // During Bike section
              DuringSportOverrideSection(
                key: const ValueKey('nutrition_targets.during_bike_section'),
                sportLabel: 'Bike',
                sportIcon: Icons.directions_bike,
                carbController: _duringBikeCarbRateController,
                sodiumController: _duringBikeSodiumRateController,
                fluidController: _duringBikeFluidRateController,
                useMetric: _useMetric,
                showHighCarbRateWarning: showBikeHighCarbWarning,
                highCarbRateWarningThreshold: _highCarbWarningThresholdGPerH,
                onHighCarbRateWarningInfoTap: _showHighCarbRateWarningInfoSheet,
                onChanged: _markChanged,
              ),

              const SizedBox(height: AppSpacing.sm),

              // During Swim section
              DuringSportOverrideSection(
                key: const ValueKey('nutrition_targets.during_swim_section'),
                sportLabel: 'Swim',
                sportIcon: Icons.pool,
                carbController: _duringSwimCarbRateController,
                sodiumController: _duringSwimSodiumRateController,
                fluidController: _duringSwimFluidRateController,
                useMetric: _useMetric,
                carbsDisabled: true,
                onChanged: _markChanged,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Post-Activity section
              _buildSectionCard(
                title: 'Post-Activity',
                children: [
                  _buildField('Carbs (g)', _postCarbsController),
                  _buildField('Protein (g)', _postProteinController),
                  _buildField('Sodium (mg)', _postSodiumController),
                  _buildField('Fluids ($fluidUnitLabel)', _postFluidController),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Reset button
              TextButton(
                onPressed: _resetAll,
                child: Text(
                  'Reset All to Defaults',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.electrolyte,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Save button
              KylePrimaryButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    Key? cardKey,
  }) {
    return BaseCard(
      key: cardKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    Key? fieldKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextFormField(
              key: fieldKey,
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                hintText: 'Auto',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
              onChanged: (_) => _markChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
