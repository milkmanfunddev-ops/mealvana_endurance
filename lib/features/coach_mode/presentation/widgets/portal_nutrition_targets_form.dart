import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../auth/domain/user_preferences.dart';
import '../providers/athlete_detail_controller.dart';

/// Simplified nutrition target overrides form for coaches.
/// Lets coaches set pre/during/post targets for an athlete.
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
  final _preSodiumCtl = TextEditingController();
  final _preFluidCtl = TextEditingController();

  // During (single sport for simplicity — applies to running)
  final _duringCarbRateCtl = TextEditingController();
  final _duringSodiumRateCtl = TextEditingController();
  final _duringFluidRateCtl = TextEditingController();

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
    _preSodiumCtl.dispose();
    _preFluidCtl.dispose();
    _duringCarbRateCtl.dispose();
    _duringSodiumRateCtl.dispose();
    _duringFluidRateCtl.dispose();
    _postCarbsCtl.dispose();
    _postProteinCtl.dispose();
    _postSodiumCtl.dispose();
    _postFluidCtl.dispose();
    super.dispose();
  }

  void _populateFromProfile() {
    final overrides = widget.athleteProfile?.nutritionTargetOverrides;
    if (overrides == null) return;

    final pre = overrides.pre;
    if (pre != null) {
      if (pre.carbsG != null) _preCarbsCtl.text = pre.carbsG!.toStringAsFixed(0);
      if (pre.proteinG != null) _preProteinCtl.text = pre.proteinG!.toStringAsFixed(0);
      if (pre.sodiumMg != null) _preSodiumCtl.text = pre.sodiumMg!.toStringAsFixed(0);
      if (pre.fluidMl != null) _preFluidCtl.text = pre.fluidMl!.toStringAsFixed(0);
    }

    // Use running during values as the default display
    final during = overrides.during ?? overrides.duringRun;
    if (during != null) {
      if (during.carbRateGPerH != null) {
        _duringCarbRateCtl.text = during.carbRateGPerH!.toStringAsFixed(0);
      }
      if (during.sodiumRateMgPerH != null) {
        _duringSodiumRateCtl.text = during.sodiumRateMgPerH!.toStringAsFixed(0);
      }
      if (during.fluidRateMlPerH != null) {
        _duringFluidRateCtl.text = during.fluidRateMlPerH!.toStringAsFixed(0);
      }
    }

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
        sodiumMg: dbl(_preSodiumCtl),
        fluidMl: dbl(_preFluidCtl),
      ),
      during: DuringActivityOverrides(
        carbRateGPerH: dbl(_duringCarbRateCtl),
        sodiumRateMgPerH: dbl(_duringSodiumRateCtl),
        fluidRateMlPerH: dbl(_duringFluidRateCtl),
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
      await ref
          .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
          .saveNutritionTargets(overrides);

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
        _preCarbsCtl, _preProteinCtl, _preSodiumCtl, _preFluidCtl,
        _duringCarbRateCtl, _duringSodiumRateCtl, _duringFluidRateCtl,
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Sodium (mg)', _preSodiumCtl),
              const SizedBox(width: 8),
              _buildField('Fluid (fl oz)', _preFluidCtl),
            ],
          ),

          const SizedBox(height: 20),

          // During Section
          _buildSectionHeader('During Activity (per hour)'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Carbs (g/hr)', _duringCarbRateCtl),
              const SizedBox(width: 8),
              _buildField('Sodium (mg/hr)', _duringSodiumRateCtl),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildField('Fluid (fl oz/hr)', _duringFluidRateCtl),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()), // spacer
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
