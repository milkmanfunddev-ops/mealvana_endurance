import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../providers/settings_controller.dart';

/// Screen for configuring default nutrition target overrides.
/// Empty fields = use algorithm defaults (null).
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

  // During-activity controllers
  final _duringCarbRateController = TextEditingController();
  final _duringSodiumRateController = TextEditingController();
  final _duringFluidRateController = TextEditingController();

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
        // During-activity
        if (overrides.during != null) {
          _setController(
              _duringCarbRateController, overrides.during!.carbRateGPerH);
          _setController(
              _duringSodiumRateController, overrides.during!.sodiumRateMgPerH);
          _setController(
              _duringFluidRateController, overrides.during!.fluidRateMlPerH);
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
      controller.text =
          value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _preCarbsController.dispose();
    _preProteinController.dispose();
    _preFatController.dispose();
    _preSodiumController.dispose();
    _preFluidController.dispose();
    _duringCarbRateController.dispose();
    _duringSodiumRateController.dispose();
    _duringFluidRateController.dispose();
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

    final during = DuringActivityOverrides(
      carbRateGPerH: _parseField(_duringCarbRateController),
      sodiumRateMgPerH: _parseField(_duringSodiumRateController),
      fluidRateMlPerH: _parseField(_duringFluidRateController),
    );

    final post = PostActivityOverrides(
      carbsG: _parseField(_postCarbsController),
      proteinG: _parseField(_postProteinController),
      sodiumMg: _parseField(_postSodiumController),
      fluidMl: _parseField(_postFluidController),
    );

    var overrides = NutritionTargetOverrides(
      pre: pre.hasAnyOverride ? pre : null,
      during: during.hasAnyOverride ? during : null,
      post: post.hasAnyOverride ? post : null,
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
      _duringCarbRateController.clear();
      _duringSodiumRateController.clear();
      _duringFluidRateController.clear();
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

            const SizedBox(height: AppSpacing.md),

            // During-Activity section
            _buildSectionCard(
              title: 'During Activity (per hour)',
              children: [
                _buildField(
                    'Carbs (g/hr)', _duringCarbRateController, 0, 120),
                _buildField(
                    'Sodium (mg/hr)', _duringSodiumRateController, 0, 2000),
                _buildField(
                    'Fluids (ml/hr)', _duringFluidRateController, 200, 3000),
              ],
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
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
