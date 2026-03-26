import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/athlete_detail_controller.dart';

/// Nutrition target overrides form for coaches.
/// Matches the settings NutritionTargetsScreen structure with:
/// - Pre: carbs, protein, fat, sodium, fluid
/// - During: 4 sport-specific sections (Run, Bike, Swim, Brick)
/// - Post: carbs, protein, sodium, fluid
class PortalNutritionTargetsForm extends ConsumerStatefulWidget {
  final String relationshipId;
  final UserProfile? athleteProfile;

  const PortalNutritionTargetsForm({
    super.key,
    required this.relationshipId,
    this.athleteProfile,
  });

  @override
  ConsumerState<PortalNutritionTargetsForm> createState() =>
      _PortalNutritionTargetsFormState();
}

class _PortalNutritionTargetsFormState
    extends ConsumerState<PortalNutritionTargetsForm> {
  bool _isSaving = false;
  bool _hasChanges = false;

  // Pre controllers
  final _preCarbsCtl = TextEditingController();
  final _preProteinCtl = TextEditingController();
  final _preFatCtl = TextEditingController();
  final _preSodiumCtl = TextEditingController();
  final _preFluidCtl = TextEditingController();

  // During Run controllers
  final _duringRunCarbRateCtl = TextEditingController();
  final _duringRunSodiumRateCtl = TextEditingController();
  final _duringRunFluidRateCtl = TextEditingController();

  // During Bike controllers
  final _duringBikeCarbRateCtl = TextEditingController();
  final _duringBikeSodiumRateCtl = TextEditingController();
  final _duringBikeFluidRateCtl = TextEditingController();

  // During Swim controllers (no carb rate — can't eat while swimming)
  final _duringSwimSodiumRateCtl = TextEditingController();
  final _duringSwimFluidRateCtl = TextEditingController();

  // During Brick controllers
  final _duringBrickCarbRateCtl = TextEditingController();
  final _duringBrickSodiumRateCtl = TextEditingController();
  final _duringBrickFluidRateCtl = TextEditingController();

  // Post controllers
  final _postCarbsCtl = TextEditingController();
  final _postProteinCtl = TextEditingController();
  final _postSodiumCtl = TextEditingController();
  final _postFluidCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populateFromProfile();
  }

  @override
  void dispose() {
    _preCarbsCtl.dispose();
    _preProteinCtl.dispose();
    _preFatCtl.dispose();
    _preSodiumCtl.dispose();
    _preFluidCtl.dispose();
    _duringRunCarbRateCtl.dispose();
    _duringRunSodiumRateCtl.dispose();
    _duringRunFluidRateCtl.dispose();
    _duringBikeCarbRateCtl.dispose();
    _duringBikeSodiumRateCtl.dispose();
    _duringBikeFluidRateCtl.dispose();
    _duringSwimSodiumRateCtl.dispose();
    _duringSwimFluidRateCtl.dispose();
    _duringBrickCarbRateCtl.dispose();
    _duringBrickSodiumRateCtl.dispose();
    _duringBrickFluidRateCtl.dispose();
    _postCarbsCtl.dispose();
    _postProteinCtl.dispose();
    _postSodiumCtl.dispose();
    _postFluidCtl.dispose();
    super.dispose();
  }

  void _populateFromProfile() {
    final overrides = widget.athleteProfile?.nutritionTargetOverrides;
    if (overrides == null) return;

    // Pre
    final pre = overrides.pre;
    if (pre != null) {
      if (pre.carbsG != null) _preCarbsCtl.text = pre.carbsG!.toStringAsFixed(0);
      if (pre.proteinG != null) _preProteinCtl.text = pre.proteinG!.toStringAsFixed(0);
      if (pre.fatG != null) _preFatCtl.text = pre.fatG!.toStringAsFixed(0);
      if (pre.sodiumMg != null) _preSodiumCtl.text = pre.sodiumMg!.toStringAsFixed(0);
      if (pre.fluidMl != null) _preFluidCtl.text = pre.fluidMl!.toStringAsFixed(0);
    }

    // During Run (fallback to legacy during)
    final duringRun = overrides.duringRun ?? overrides.during;
    if (duringRun != null) {
      if (duringRun.carbRateGPerH != null) {
        _duringRunCarbRateCtl.text = duringRun.carbRateGPerH!.toStringAsFixed(0);
      }
      if (duringRun.sodiumRateMgPerH != null) {
        _duringRunSodiumRateCtl.text = duringRun.sodiumRateMgPerH!.toStringAsFixed(0);
      }
      if (duringRun.fluidRateMlPerH != null) {
        _duringRunFluidRateCtl.text = duringRun.fluidRateMlPerH!.toStringAsFixed(0);
      }
    }

    // During Bike (fallback to legacy during)
    final duringBike = overrides.duringCycling ?? overrides.during;
    if (duringBike != null) {
      if (duringBike.carbRateGPerH != null) {
        _duringBikeCarbRateCtl.text = duringBike.carbRateGPerH!.toStringAsFixed(0);
      }
      if (duringBike.sodiumRateMgPerH != null) {
        _duringBikeSodiumRateCtl.text = duringBike.sodiumRateMgPerH!.toStringAsFixed(0);
      }
      if (duringBike.fluidRateMlPerH != null) {
        _duringBikeFluidRateCtl.text = duringBike.fluidRateMlPerH!.toStringAsFixed(0);
      }
    }

    // During Swim (fallback to legacy during; no carb rate for swimming)
    final duringSwim = overrides.duringSwimming ?? overrides.during;
    if (duringSwim != null) {
      if (duringSwim.sodiumRateMgPerH != null) {
        _duringSwimSodiumRateCtl.text = duringSwim.sodiumRateMgPerH!.toStringAsFixed(0);
      }
      if (duringSwim.fluidRateMlPerH != null) {
        _duringSwimFluidRateCtl.text = duringSwim.fluidRateMlPerH!.toStringAsFixed(0);
      }
    }

    // During Brick (fallback to legacy during)
    final duringBrick = overrides.duringBrick ?? overrides.during;
    if (duringBrick != null) {
      if (duringBrick.carbRateGPerH != null) {
        _duringBrickCarbRateCtl.text = duringBrick.carbRateGPerH!.toStringAsFixed(0);
      }
      if (duringBrick.sodiumRateMgPerH != null) {
        _duringBrickSodiumRateCtl.text = duringBrick.sodiumRateMgPerH!.toStringAsFixed(0);
      }
      if (duringBrick.fluidRateMlPerH != null) {
        _duringBrickFluidRateCtl.text = duringBrick.fluidRateMlPerH!.toStringAsFixed(0);
      }
    }

    // Post
    final post = overrides.post;
    if (post != null) {
      if (post.carbsG != null) _postCarbsCtl.text = post.carbsG!.toStringAsFixed(0);
      if (post.proteinG != null) _postProteinCtl.text = post.proteinG!.toStringAsFixed(0);
      if (post.sodiumMg != null) _postSodiumCtl.text = post.sodiumMg!.toStringAsFixed(0);
      if (post.fluidMl != null) _postFluidCtl.text = post.fluidMl!.toStringAsFixed(0);
    }
  }

  NutritionTargetOverrides _buildOverrides() {
    double? dbl(TextEditingController c) {
      final text = c.text.trim();
      return text.isEmpty ? null : double.tryParse(text);
    }

    return NutritionTargetOverrides(
      pre: PreActivityOverrides(
        carbsG: dbl(_preCarbsCtl),
        proteinG: dbl(_preProteinCtl),
        fatG: dbl(_preFatCtl),
        sodiumMg: dbl(_preSodiumCtl),
        fluidMl: dbl(_preFluidCtl),
      ),
      duringRun: DuringActivityOverrides(
        carbRateGPerH: dbl(_duringRunCarbRateCtl),
        sodiumRateMgPerH: dbl(_duringRunSodiumRateCtl),
        fluidRateMlPerH: dbl(_duringRunFluidRateCtl),
      ),
      duringCycling: DuringActivityOverrides(
        carbRateGPerH: dbl(_duringBikeCarbRateCtl),
        sodiumRateMgPerH: dbl(_duringBikeSodiumRateCtl),
        fluidRateMlPerH: dbl(_duringBikeFluidRateCtl),
      ),
      duringSwimming: DuringActivityOverrides(
        sodiumRateMgPerH: dbl(_duringSwimSodiumRateCtl),
        fluidRateMlPerH: dbl(_duringSwimFluidRateCtl),
      ),
      duringBrick: DuringActivityOverrides(
        carbRateGPerH: dbl(_duringBrickCarbRateCtl),
        sodiumRateMgPerH: dbl(_duringBrickSodiumRateCtl),
        fluidRateMlPerH: dbl(_duringBrickFluidRateCtl),
      ),
      post: PostActivityOverrides(
        carbsG: dbl(_postCarbsCtl),
        proteinG: dbl(_postProteinCtl),
        sodiumMg: dbl(_postSodiumCtl),
        fluidMl: dbl(_postFluidCtl),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final overrides = _buildOverrides();
      final clamped = NutritionTargetGuardrails.clampAll(overrides);
      await ref
          .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
          .saveNutritionTargets(clamped);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      MealvanaSnackbar.showSuccess(context, 'Nutrition targets saved');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      MealvanaSnackbar.showError(context, 'Failed to save targets');
    }
  }

  Future<void> _clearAll() async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
          .saveNutritionTargets(const NutritionTargetOverrides());

      if (!mounted) return;

      // Clear all controllers
      for (final c in [
        _preCarbsCtl, _preProteinCtl, _preFatCtl, _preSodiumCtl, _preFluidCtl,
        _duringRunCarbRateCtl, _duringRunSodiumRateCtl, _duringRunFluidRateCtl,
        _duringBikeCarbRateCtl, _duringBikeSodiumRateCtl, _duringBikeFluidRateCtl,
        _duringSwimSodiumRateCtl, _duringSwimFluidRateCtl,
        _duringBrickCarbRateCtl, _duringBrickSodiumRateCtl, _duringBrickFluidRateCtl,
        _postCarbsCtl, _postProteinCtl, _postSodiumCtl, _postFluidCtl,
      ]) {
        c.clear();
      }

      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      MealvanaSnackbar.showSuccess(context, 'Targets reset to defaults');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      MealvanaSnackbar.showError(context, 'Failed to reset targets');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Nutrition Target Overrides',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Empty fields use algorithm defaults. During targets only apply to activities >= 90 min.',
            style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Pre-Activity Section
          _buildSectionHeader('Pre-Activity'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g)', _preCarbsCtl),
              const SizedBox(width: 8),
              _buildField('Protein (g)', _preProteinCtl),
              const SizedBox(width: 8),
              _buildField('Fat (g)', _preFatCtl),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Sodium (mg)', _preSodiumCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz)', _preFluidCtl),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()), // spacer
            ],
          ),

          const SizedBox(height: 20),

          // During Run Section
          _buildSportSectionHeader('During Run', Icons.directions_run),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g/hr)', _duringRunCarbRateCtl),
              const SizedBox(width: 8),
              _buildField('Sodium (mg/hr)', _duringRunSodiumRateCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz/hr)', _duringRunFluidRateCtl),
            ],
          ),

          const SizedBox(height: 16),

          // During Bike Section
          _buildSportSectionHeader('During Bike', Icons.directions_bike),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g/hr)', _duringBikeCarbRateCtl),
              const SizedBox(width: 8),
              _buildField('Sodium (mg/hr)', _duringBikeSodiumRateCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz/hr)', _duringBikeFluidRateCtl),
            ],
          ),

          const SizedBox(height: 16),

          // During Swim Section
          _buildSportSectionHeader('During Swim', Icons.pool),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Sodium (mg/hr)', _duringSwimSodiumRateCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz/hr)', _duringSwimFluidRateCtl),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()), // spacer
            ],
          ),

          const SizedBox(height: 16),

          // During Brick Section
          _buildSportSectionHeader('During Brick', Icons.fitness_center),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g/hr)', _duringBrickCarbRateCtl),
              const SizedBox(width: 8),
              _buildField('Sodium (mg/hr)', _duringBrickSodiumRateCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz/hr)', _duringBrickFluidRateCtl),
            ],
          ),

          const SizedBox(height: 20),

          // Post-Activity Section
          _buildSectionHeader('Post-Activity'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g)', _postCarbsCtl),
              const SizedBox(width: 8),
              _buildField('Protein (g)', _postProteinCtl),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Sodium (mg)', _postSodiumCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz)', _postFluidCtl),
            ],
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _clearAll,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.blackberryLight),
                    foregroundColor: AppColors.textDarkSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Reset to Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electrolyte,
                    foregroundColor: AppColors.blackberry,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Targets'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.electrolyte,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSportSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.electrolyte, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.electrolyte,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: const TextStyle(color: AppColors.cream, fontSize: 14),
            onChanged: (_) {
              if (!_hasChanges) setState(() => _hasChanges = true);
            },
            decoration: InputDecoration(
              hintText: 'Default',
              hintStyle: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.blackberryDark,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.blackberryLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.blackberryLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.electrolyte),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
