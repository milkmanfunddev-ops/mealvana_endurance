import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../daily_macros/domain/enums.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../providers/settings_controller.dart';
import '../../../auth/data/user_repository.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';
import '../../../integrations/presentation/widgets/garmin_attribution_message.dart';

class NutritionProfileScreen extends ConsumerStatefulWidget {
  const NutritionProfileScreen({super.key});

  @override
  ConsumerState<NutritionProfileScreen> createState() =>
      _NutritionProfileScreenState();
}

class _NutritionProfileScreenState
    extends ConsumerState<NutritionProfileScreen> {
  final _weightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _weeklyHoursController = TextEditingController();

  Lifestyle _lifestyle = Lifestyle.mixed;
  bool _carbCycleOptIn = false;
  TrainingPhase _trainingPhase = TrainingPhase.base;
  bool _hasChanges = false;
  bool _weightFromGarmin = false;
  bool _bodyFatFromGarmin = false;
  bool _isSaving = false;

  // Mirrors the user's unitSystemProvider preference. Kept as local state
  // (rather than watched directly in build) so the weight/height fields can
  // be converted in place — via `ref.listen` below — if the preference
  // changes elsewhere while this screen is open.
  bool _useMetric = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _heightCmController.dispose();
    _bodyFatController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  /// Converts whatever is currently entered in the weight/height fields
  /// to match [toMetric], so a mid-session unit-preference change doesn't
  /// silently mismatch the displayed value against its label. Best-effort —
  /// unparsable/empty fields are left untouched.
  void _convertFieldsForUnitChange({required bool toMetric}) {
    if (toMetric) {
      final lbs = double.tryParse(_weightController.text);
      if (lbs != null) {
        _weightController.text = UnitFormatter.poundsToKg(
          lbs,
        ).toStringAsFixed(1);
      }
      final feet = int.tryParse(_heightFeetController.text);
      final inches = int.tryParse(_heightInchesController.text);
      if (feet != null && inches != null) {
        final totalInches = (feet * 12) + inches;
        _heightCmController.text = UnitFormatter.totalInchesToCm(
          totalInches,
        ).toString();
      }
    } else {
      final kg = double.tryParse(_weightController.text);
      if (kg != null) {
        _weightController.text = UnitFormatter.kgToPounds(
          kg,
        ).toStringAsFixed(0);
      }
      final cm = int.tryParse(_heightCmController.text);
      if (cm != null) {
        final (feet, inches) = UnitFormatter.cmToFeetInches(cm);
        _heightFeetController.text = feet.toString();
        _heightInchesController.text = inches.toString();
      }
    }
  }

  Future<void> _loadCurrentValues() async {
    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    if (profile == null || !mounted) return;

    // Populate fields in imperial (the canonical storage unit) first, so the
    // screen renders immediately without waiting on the unit-preference
    // lookup below.
    setState(() {
      _weightController.text = profile.weightPounds.toStringAsFixed(0);
      _heightFeetController.text = profile.heightFeet.toString();
      _heightInchesController.text = profile.heightInches.toString();
      if (profile.bodyFatPct != null) {
        _bodyFatController.text = profile.bodyFatPct!.toStringAsFixed(1);
      }
      _lifestyle = profile.lifestyle;
      if (profile.typicalWeeklyHours != null) {
        _weeklyHoursController.text = profile.typicalWeeklyHours!
            .toStringAsFixed(1);
      }
      _carbCycleOptIn = profile.carbCycleOptIn;
      _trainingPhase = profile.trainingPhase;
    });

    // Apply the user's unit preference to the weight/height display.
    // Best-effort — falls back to the imperial display set above if the
    // preference can't be resolved.
    try {
      final unitSystem = await ref.read(unitSystemProvider.future);
      if (unitSystem == UnitSystem.metric && mounted) {
        setState(() {
          _convertFieldsForUnitChange(toMetric: true);
          _useMetric = true;
        });
      }
    } catch (_) {
      // Non-fatal — default to imperial display.
    }

    // Garmin auto-fill: if Garmin's latest body-comp reading is authoritative
    // (newer than the user's manual entry, within 30-day staleness window),
    // overwrite weight + body-fat fields. User edits clear the corresponding
    // _fromGarmin flag and hide the chip.
    try {
      final garminData = await ref.read(
        garminLastBodyCompProvider(profile.id).future,
      );
      if (!mounted || garminData == null) return;

      final userWeightKg = profile.weightPounds * 0.453592;
      final weightAuthoritative = isGarminAuthoritativeForWeight(
        garmin: garminData,
        userWeightKg: userWeightKg,
        userUpdatedAt: profile.weightPoundsUpdatedAt,
      );
      if (weightAuthoritative && garminData.weightKg != null) {
        setState(() {
          _weightController.text = _useMetric
              ? garminData.weightKg!.toStringAsFixed(1)
              : UnitFormatter.kgToPounds(garminData.weightKg!)
                    .round()
                    .toString();
          _weightFromGarmin = true;
        });
      }

      final bodyFatAuthoritative = isGarminAuthoritativeForBodyFat(
        garmin: garminData,
        userBodyFatPct: profile.bodyFatPct,
        userUpdatedAt: profile.bodyFatPctUpdatedAt,
      );
      if (bodyFatAuthoritative && garminData.bodyFatPct != null) {
        setState(() {
          _bodyFatController.text = garminData.bodyFatPct!.toStringAsFixed(1);
          _bodyFatFromGarmin = true;
        });
      }
    } catch (_) {
      // Non-fatal — Garmin auto-fill is best-effort.
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final profile = await userRepository.getCurrentUser();
      if (profile == null) return;

      // Convert display values (which are in whatever unit the user is
      // viewing) back to the canonical storage units: pounds + feet/inches.
      final weightEntered = double.tryParse(_weightController.text);
      final weightLbs = weightEntered == null
          ? null
          : (_useMetric
                ? UnitFormatter.kgToPounds(weightEntered)
                : weightEntered);

      int? heightFeet;
      int? heightInches;
      if (_useMetric) {
        final cm = int.tryParse(_heightCmController.text);
        if (cm != null) {
          final converted = UnitFormatter.cmToFeetInches(cm);
          heightFeet = converted.$1;
          heightInches = converted.$2;
        }
      } else {
        heightFeet = int.tryParse(_heightFeetController.text);
        heightInches = int.tryParse(_heightInchesController.text);
      }

      final bodyFat = double.tryParse(_bodyFatController.text);
      final weeklyHours = double.tryParse(_weeklyHoursController.text);

      // Only bump weight_pounds_updated_at when the user edits the field
      // away from whatever Garmin auto-filled. If the displayed value still
      // matches Garmin's reading, leave the timestamp on Garmin's so the
      // edge-function resolver can still resolve weight correctly.
      final weightChanged = weightLbs != null &&
          !_weightFromGarmin &&
          weightLbs != profile.weightPounds;
      final bodyFatChanged = bodyFat != profile.bodyFatPct &&
          !_bodyFatFromGarmin;

      final updated = profile.copyWith(
        weightPounds: weightLbs ?? profile.weightPounds,
        weightPoundsUpdatedAt: weightChanged
            ? DateTime.now().toUtc()
            : profile.weightPoundsUpdatedAt,
        heightFeet: heightFeet ?? profile.heightFeet,
        heightInches: heightInches ?? profile.heightInches,
        bodyFatPct: bodyFat,
        bodyFatPctUpdatedAt: bodyFatChanged
            ? DateTime.now().toUtc()
            : profile.bodyFatPctUpdatedAt,
        lifestyle: _lifestyle,
        typicalWeeklyHours: weeklyHours,
        carbCycleOptIn: _carbCycleOptIn,
        trainingPhase: _trainingPhase,
      );

      await userRepository.updateUserProfile(updated);

      // Invalidate daily macros so they recalculate
      ref.invalidate(settingsControllerProvider);

      if (mounted) {
        MealvanaSnackbar.showSuccess(context, 'Nutrition profile saved');
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to save: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    // React to unit-preference changes made elsewhere (e.g. another settings
    // screen) while this screen is mounted — convert the displayed values in
    // place so they never mismatch their unit label.
    ref.listen<AsyncValue<UnitSystem>>(unitSystemProvider, (previous, next) {
      final newUseMetric = next.value == UnitSystem.metric;
      if (newUseMetric != _useMetric) {
        setState(() {
          _convertFieldsForUnitChange(toMetric: newUseMetric);
          _useMetric = newUseMetric;
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(
          key: ValueKey('nutrition_profile.back_button'),
        ),
        title: Text(
          key: const ValueKey('nutrition_profile.title'),
          'Body Composition',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              key: const ValueKey('nutrition_profile.save_button'),
              onPressed: _isSaving ? null : _save,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.electrolyte,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: ContentArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Weight (with Garmin auto-fill when authoritative)
              _buildSectionLabel(
                context,
                'Weight',
                labelKey: const ValueKey('body_composition.weight_section'),
              ),
              if (_weightFromGarmin) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: GarminAttributionMessage(
                    subject: 'Weight',
                    compact: true,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _buildWeightInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Height (feet + inches)
              _buildSectionLabel(
                context,
                'Height',
                labelKey: const ValueKey('body_composition.height_section'),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildHeightInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Body Fat %
              _buildSectionLabel(
                context,
                'Body Fat % (optional)',
                labelKey: const ValueKey('nutrition_profile.body_fat_section'),
              ),
              if (_bodyFatFromGarmin) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: GarminAttributionMessage(
                    subject: 'Body fat %',
                    compact: true,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _buildBodyFatInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Lifestyle
              _buildSectionLabel(
                context,
                'Daily Activity Level',
                labelKey: const ValueKey(
                  'nutrition_profile.activity_level_section',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildLifestyleSelector(context),

              const SizedBox(height: AppSpacing.xl),

              // Weekly Hours
              _buildSectionLabel(
                context,
                'Typical Weekly Training Hours',
                labelKey: const ValueKey(
                  'nutrition_profile.training_hours_section',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildWeeklyHoursInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Carb Cycling
              _buildCarbCyclingToggle(context),

              const SizedBox(height: AppSpacing.xl),

              // Training Phase
              _buildSectionLabel(
                context,
                'Training Phase',
                labelKey: const ValueKey(
                  'nutrition_profile.training_phase_section',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildTrainingPhaseSelector(context),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label, {
    Key? labelKey,
  }) {
    return Text(
      key: labelKey,
      label,
      // Section labels here use Sansita (the heading face) rather than
      // Compadre's capitalized-look subtitle style — matches how page
      // titles are rendered and reads as proper headings, not labels.
      style: AppTextStyles.sectionTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 18,
      ),
    );
  }

  Widget _buildWeightInput(BuildContext context) {
    return BaseCard(
      child: KyleInputField(
        key: const ValueKey('body_composition.weight_field'),
        controller: _weightController,
        hintText: _useMetric ? 'e.g., 75' : 'e.g., 165',
        suffixText: _useMetric ? 'kg' : 'lbs',
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (_) {
          // User edit supersedes Garmin — clear the chip and mark dirty.
          if (_weightFromGarmin) {
            setState(() => _weightFromGarmin = false);
          }
          _markChanged();
        },
      ),
    );
  }

  Widget _buildHeightInput(BuildContext context) {
    if (_useMetric) {
      return BaseCard(
        child: KyleInputField(
          key: const ValueKey('body_composition.height_cm_field'),
          controller: _heightCmController,
          hintText: 'cm',
          suffixText: 'cm',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => _markChanged(),
        ),
      );
    }
    return BaseCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: KyleInputField(
              key: const ValueKey('body_composition.height_ft_field'),
              controller: _heightFeetController,
              hintText: 'ft',
              suffixText: 'ft',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => _markChanged(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: KyleInputField(
              key: const ValueKey('body_composition.height_in_field'),
              controller: _heightInchesController,
              hintText: 'in',
              suffixText: 'in',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => _markChanged(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyFatInput(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Used for more accurate RMR calculation (Cunningham formula). Leave blank to use standard formula.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KyleInputField(
            key: const ValueKey('nutrition_profile.body_fat_field'),
            controller: _bodyFatController,
            hintText: 'e.g., 15.0',
            suffixText: '%',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')),
            ],
            onChanged: (_) {
              // User edit supersedes Garmin — clear the chip and mark dirty.
              if (_bodyFatFromGarmin) {
                setState(() => _bodyFatFromGarmin = false);
              }
              _markChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleSelector(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your daily activity level outside of training.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...Lifestyle.values.map(
            (lifestyle) => _buildRadioTile(
              context: context,
              tileKey: ValueKey(
                'nutrition_profile.activity_${lifestyle.name}_button',
              ),
              title: lifestyle.displayName,
              subtitle: _lifestyleDescription(lifestyle),
              selected: _lifestyle == lifestyle,
              onTap: () {
                setState(() => _lifestyle = lifestyle);
                _markChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _lifestyleDescription(Lifestyle lifestyle) {
    switch (lifestyle) {
      case Lifestyle.desk:
        return 'Mostly sitting (office work)';
      case Lifestyle.mixed:
        return 'Some movement throughout the day';
      case Lifestyle.active:
        return 'On your feet most of the day';
      case Lifestyle.veryActive:
        return 'Physically demanding job or very active';
    }
  }

  Widget _buildWeeklyHoursInput(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your typical training volume per week. Used for load adjustment calculations.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          KyleInputField(
            key: const ValueKey('nutrition_profile.training_hours_field'),
            controller: _weeklyHoursController,
            hintText: 'e.g., 10.0',
            suffixText: 'hrs/week',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}\.?\d{0,1}')),
            ],
            onChanged: (_) => _markChanged(),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbCyclingToggle(BuildContext context) {
    return BaseCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carb Cycling',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Reduce carbs on easy/rest days to promote metabolic flexibility. Only applies to qualifying low-intensity days.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          KyleSwitch(
            key: const ValueKey('nutrition_profile.carb_cycling_toggle'),
            value: _carbCycleOptIn,
            onChanged: (value) {
              setState(() => _carbCycleOptIn = value);
              _markChanged();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingPhaseSelector(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your current training phase affects macro periodization.',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...TrainingPhase.values.map(
            (phase) => _buildRadioTile(
              context: context,
              tileKey: ValueKey('nutrition_profile.phase_${phase.name}_button'),
              title: phase.displayName,
              subtitle: _phaseDescription(phase),
              selected: _trainingPhase == phase,
              onTap: () {
                setState(() => _trainingPhase = phase);
                _markChanged();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _phaseDescription(TrainingPhase phase) {
    switch (phase) {
      case TrainingPhase.base:
        return 'Building aerobic fitness';
      case TrainingPhase.build:
        return 'Increasing intensity (+8% carbs, +5% protein)';
      case TrainingPhase.peak:
        return 'Race-specific training (+12% carbs, +10% protein)';
      case TrainingPhase.taper:
        return 'Reduced volume before race (-12% carbs)';
      case TrainingPhase.raceWeek:
        return 'Final preparation for race day';
      case TrainingPhase.offSeason:
        return 'Recovery and base maintenance (-20% carbs)';
    }
  }

  Widget _buildRadioTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    Key? tileKey,
  }) {
    return InkWell(
      key: tileKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? AppColors.electrolyte
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
