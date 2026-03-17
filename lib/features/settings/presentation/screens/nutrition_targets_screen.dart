import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../providers/settings_controller.dart';
import '../widgets/during_sport_override_section.dart';

/// Screen for configuring default nutrition target overrides.
/// Empty fields = use algorithm defaults (null).
///
/// During-workout overrides are split by sport (Run, Bike, Swim, Brick).
/// During overrides only apply to activities >= 90 minutes.
class NutritionTargetsScreen extends ConsumerStatefulWidget {
  const NutritionTargetsScreen({super.key});

  @override
  ConsumerState<NutritionTargetsScreen> createState() =>
      _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState
    extends ConsumerState<NutritionTargetsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _hasChanges = false;
  bool _isSaving = false;

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

  // During Brick controllers
  final _duringBrickCarbRateController = TextEditingController();
  final _duringBrickSodiumRateController = TextEditingController();
  final _duringBrickFluidRateController = TextEditingController();

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
          _setController(_preFluidController, overrides.pre!.fluidMl);
        }

        // During Run (sport-specific, with legacy fallback)
        final duringRun = overrides.duringRun ?? overrides.during;
        if (duringRun != null) {
          _setController(_duringRunCarbRateController, duringRun.carbRateGPerH);
          _setController(
              _duringRunSodiumRateController, duringRun.sodiumRateMgPerH);
          _setController(
              _duringRunFluidRateController, duringRun.fluidRateMlPerH);
        }

        // During Bike (sport-specific, with legacy fallback)
        final duringBike = overrides.duringCycling ?? overrides.during;
        if (duringBike != null) {
          _setController(
              _duringBikeCarbRateController, duringBike.carbRateGPerH);
          _setController(
              _duringBikeSodiumRateController, duringBike.sodiumRateMgPerH);
          _setController(
              _duringBikeFluidRateController, duringBike.fluidRateMlPerH);
        }

        // During Swim (sport-specific, with legacy fallback)
        final duringSwim = overrides.duringSwimming ?? overrides.during;
        if (duringSwim != null) {
          // Don't load carbs for swimming (carbs N/A while swimming)
          _setController(
              _duringSwimSodiumRateController, duringSwim.sodiumRateMgPerH);
          _setController(
              _duringSwimFluidRateController, duringSwim.fluidRateMlPerH);
        }

        // During Brick (sport-specific, with legacy fallback)
        final duringBrick = overrides.duringBrick ?? overrides.during;
        if (duringBrick != null) {
          _setController(
              _duringBrickCarbRateController, duringBrick.carbRateGPerH);
          _setController(
              _duringBrickSodiumRateController, duringBrick.sodiumRateMgPerH);
          _setController(
              _duringBrickFluidRateController, duringBrick.fluidRateMlPerH);
        }

        // Post-activity
        if (overrides.post != null) {
          _setController(_postCarbsController, overrides.post!.carbsG);
          _setController(_postProteinController, overrides.post!.proteinG);
          _setController(_postSodiumController, overrides.post!.sodiumMg);
          _setController(_postFluidController, overrides.post!.fluidMl);
        }
      });
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
    _duringBrickCarbRateController.dispose();
    _duringBrickSodiumRateController.dispose();
    _duringBrickFluidRateController.dispose();
    _postCarbsController.dispose();
    _postProteinController.dispose();
    _postSodiumController.dispose();
    _postFluidController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  double? _parseField(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  DuringActivityOverrides? _parseDuringOverride({
    required TextEditingController carbController,
    required TextEditingController sodiumController,
    required TextEditingController fluidController,
  }) {
    final during = DuringActivityOverrides(
      carbRateGPerH: _parseField(carbController),
      sodiumRateMgPerH: _parseField(sodiumController),
      fluidRateMlPerH: _parseField(fluidController),
    );
    return during.hasAnyOverride ? during : null;
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final pre = PreActivityOverrides(
      carbsG: _parseField(_preCarbsController),
      proteinG: _parseField(_preProteinController),
      fatG: _parseField(_preFatController),
      sodiumMg: _parseField(_preSodiumController),
      fluidMl: _parseField(_preFluidController),
    );

    final post = PostActivityOverrides(
      carbsG: _parseField(_postCarbsController),
      proteinG: _parseField(_postProteinController),
      sodiumMg: _parseField(_postSodiumController),
      fluidMl: _parseField(_postFluidController),
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
      duringBrick: _parseDuringOverride(
        carbController: _duringBrickCarbRateController,
        sodiumController: _duringBrickSodiumRateController,
        fluidController: _duringBrickFluidRateController,
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

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });
        MealvanaSnackbar.showSuccess(context, 'Nutrition targets saved');
      }
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
      _duringBrickCarbRateController.clear();
      _duringBrickSodiumRateController.clear();
      _duringBrickFluidRateController.clear();
      _postCarbsController.clear();
      _postProteinController.clear();
      _postSodiumController.clear();
      _postFluidController.clear();
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CustomAppBarBackButton(),
        title: Text(
          'Nutrition Targets',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Info banner
            BaseCard(
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Pre-Activity section
            _buildSectionCard(
              title: 'Pre-Activity',
              children: [
                _buildField('Carbs (g)', _preCarbsController, 0, 500),
                _buildField('Protein (g)', _preProteinController, 0, 100),
                _buildField('Fat (g)', _preFatController, 0, 100),
                _buildField('Sodium (mg)', _preSodiumController, 0, 3000),
                _buildField('Fluids (ml)', _preFluidController, 0, 2000),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // 90-minute note
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Text(
                'During-workout targets only apply to activities 90 minutes or longer.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // During Run section
            DuringSportOverrideSection(
              sportLabel: 'Run',
              sportIcon: Icons.directions_run,
              carbController: _duringRunCarbRateController,
              sodiumController: _duringRunSodiumRateController,
              fluidController: _duringRunFluidRateController,
              maxCarbRate: NutritionTargetGuardrails.duringMaxCarbRateRunning,
              onChanged: _markChanged,
            ),

            const SizedBox(height: AppSpacing.sm),

            // During Bike section
            DuringSportOverrideSection(
              sportLabel: 'Bike',
              sportIcon: Icons.directions_bike,
              carbController: _duringBikeCarbRateController,
              sodiumController: _duringBikeSodiumRateController,
              fluidController: _duringBikeFluidRateController,
              maxCarbRate: NutritionTargetGuardrails.duringMaxCarbRateCycling,
              onChanged: _markChanged,
            ),

            const SizedBox(height: AppSpacing.sm),

            // During Swim section
            DuringSportOverrideSection(
              sportLabel: 'Swim',
              sportIcon: Icons.pool,
              carbController: _duringSwimCarbRateController,
              sodiumController: _duringSwimSodiumRateController,
              fluidController: _duringSwimFluidRateController,
              maxCarbRate: NutritionTargetGuardrails.duringMaxCarbRateSwimming,
              carbsDisabled: true,
              onChanged: _markChanged,
            ),

            const SizedBox(height: AppSpacing.sm),

            // During Brick section
            DuringSportOverrideSection(
              sportLabel: 'Brick',
              sportIcon: Icons.link,
              carbController: _duringBrickCarbRateController,
              sodiumController: _duringBrickSodiumRateController,
              fluidController: _duringBrickFluidRateController,
              maxCarbRate: NutritionTargetGuardrails.duringMaxCarbRateBrick,
              onChanged: _markChanged,
            ),

            const SizedBox(height: AppSpacing.md),

            // Post-Activity section
            _buildSectionCard(
              title: 'Post-Activity',
              children: [
                _buildField('Carbs (g)', _postCarbsController, 0, 500),
                _buildField('Protein (g)', _postProteinController, 0, 100),
                _buildField('Sodium (mg)', _postSodiumController, 0, 2000),
                _buildField('Fluids (ml)', _postFluidController, 0, 3000),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electrolyte,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return BaseCard(
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
    TextEditingController controller,
    double min,
    double max,
  ) {
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = double.tryParse(value.trim());
                if (parsed == null) return 'Invalid';
                if (parsed < min || parsed > max) {
                  return '${min.toInt()}-${max.toInt()}';
                }
                return null;
              },
              onChanged: (_) => _markChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
