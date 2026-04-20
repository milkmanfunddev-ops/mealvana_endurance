import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/custom_app_bar_back_button.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../daily_macros/domain/enums.dart';
import '../providers/settings_controller.dart';
import '../../../auth/data/user_repository.dart';
import '../../../integrations/presentation/providers/integrations_providers.dart';

class NutritionProfileScreen extends ConsumerStatefulWidget {
  const NutritionProfileScreen({super.key});

  @override
  ConsumerState<NutritionProfileScreen> createState() =>
      _NutritionProfileScreenState();
}

class _NutritionProfileScreenState
    extends ConsumerState<NutritionProfileScreen> {
  final _bodyFatController = TextEditingController();
  final _weeklyHoursController = TextEditingController();

  Lifestyle _lifestyle = Lifestyle.mixed;
  bool _carbCycleOptIn = false;
  TrainingPhase _trainingPhase = TrainingPhase.base;
  bool _hasChanges = false;
  bool _bodyFatFromGarmin = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  @override
  void dispose() {
    _bodyFatController.dispose();
    _weeklyHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentValues() async {
    final userRepository = await ref.read(userRepositoryProvider.future);
    final profile = await userRepository.getCurrentUser();
    if (profile == null || !mounted) return;

    setState(() {
      if (profile.bodyFatPct != null) {
        _bodyFatController.text = profile.bodyFatPct!.toStringAsFixed(1);
      }
      _lifestyle = profile.lifestyle;
      if (profile.typicalWeeklyHours != null) {
        _weeklyHoursController.text = profile.typicalWeeklyHours!.toStringAsFixed(1);
      }
      _carbCycleOptIn = profile.carbCycleOptIn;
      _trainingPhase = profile.trainingPhase;
    });

    // If body fat is empty, try to populate from Garmin integration
    if (profile.bodyFatPct == null) {
      try {
        final integrationsRepo = ref.read(integrationsRepositoryProvider);
        final garminIntegration = await integrationsRepo.getIntegration(
          profile.id,
          'garmin',
        );
        if (garminIntegration?.isActive == true &&
            garminIntegration?.providerAthleteBodyFatPct != null &&
            mounted) {
          setState(() {
            _bodyFatController.text =
                garminIntegration!.providerAthleteBodyFatPct!
                    .toStringAsFixed(1);
            _bodyFatFromGarmin = true;
          });
        }
      } catch (_) {
        // Non-fatal — body fat from Garmin is best-effort
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final userRepository = await ref.read(userRepositoryProvider.future);
      final profile = await userRepository.getCurrentUser();
      if (profile == null) return;

      final bodyFat = double.tryParse(_bodyFatController.text);
      final weeklyHours = double.tryParse(_weeklyHoursController.text);

      final updated = profile.copyWith(
        bodyFatPct: bodyFat,
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const CustomAppBarBackButton(),
        title: Text(
          'Nutrition Profile',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
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

              // Body Fat %
              _buildSectionLabel(context, 'Body Fat % (optional)'),
              // Garmin brand attribution (required by Garmin API Brand Guidelines)
              if (_bodyFatFromGarmin) ...[
                const SizedBox(height: 2),
                Text(
                  'Data from Garmin',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _buildBodyFatInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Lifestyle
              _buildSectionLabel(context, 'Daily Activity Level'),
              const SizedBox(height: AppSpacing.sm),
              _buildLifestyleSelector(context),

              const SizedBox(height: AppSpacing.xl),

              // Weekly Hours
              _buildSectionLabel(context, 'Typical Weekly Training Hours'),
              const SizedBox(height: AppSpacing.sm),
              _buildWeeklyHoursInput(context),

              const SizedBox(height: AppSpacing.xl),

              // Carb Cycling
              _buildCarbCyclingToggle(context),

              const SizedBox(height: AppSpacing.xl),

              // Training Phase
              _buildSectionLabel(context, 'Training Phase'),
              const SizedBox(height: AppSpacing.sm),
              _buildTrainingPhaseSelector(context),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: AppTextStyles.subtitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
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
            controller: _bodyFatController,
            hintText: 'e.g., 15.0',
            suffixText: '%',
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
          ...Lifestyle.values.map((lifestyle) => _buildRadioTile(
                context: context,
                title: lifestyle.displayName,
                subtitle: _lifestyleDescription(lifestyle),
                selected: _lifestyle == lifestyle,
                onTap: () {
                  setState(() => _lifestyle = lifestyle);
                  _markChanged();
                },
              )),
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
          ...TrainingPhase.values.map((phase) => _buildRadioTile(
                context: context,
                title: phase.displayName,
                subtitle: _phaseDescription(phase),
                selected: _trainingPhase == phase,
                onTap: () {
                  setState(() => _trainingPhase = phase);
                  _markChanged();
                },
              )),
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
  }) {
    return InkWell(
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
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
