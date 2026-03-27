import 'package:flutter/material.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

class NutritionTargetsHelpBottomSheet extends StatelessWidget {
  const NutritionTargetsHelpBottomSheet({
    super.key,
    required this.settingsState,
  });

  final SettingsState? settingsState;

  static Future<void> show(BuildContext context, SettingsState? settingsState) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          NutritionTargetsHelpBottomSheet(settingsState: settingsState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _UserDefaultsProfile.fromSettings(settingsState);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.sm,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'How Auto Defaults Work',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Empty fields use generate-macros-v4 defaults for each activity.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRuleCard(context),
                      const SizedBox(height: AppSpacing.sm),
                      _buildPreCard(context, profile),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDuringCard(context, profile),
                      const SizedBox(height: AppSpacing.sm),
                      _buildScopeCard(context),
                      const SizedBox(height: AppSpacing.sm),
                      _buildSourceCard(context),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleCard(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'At a glance'),
          const SizedBox(height: AppSpacing.xs),
          _line(context, '1. Empty field = auto default from the algorithm.'),
          _line(
            context,
            '2. Filled field = override that value for future plans.',
          ),
          _line(
            context,
            '3. Swim during carbs stay at 0 (no in-swim carb target).',
          ),
        ],
      ),
    );
  }

  Widget _buildPreCard(BuildContext context, _UserDefaultsProfile profile) {
    final oneHour = _preWorkoutCarbs(profile.weightKg, 1.0);
    final twoHalfHours = _preWorkoutCarbs(profile.weightKg, 2.5);
    final fourHours = _preWorkoutCarbs(profile.weightKg, 4.0);

    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'Pre defaults (carbs)'),
          const SizedBox(height: AppSpacing.xs),
          _line(context, 'Formula: weight_kg x clamp(hours_before, 0.5, 4.0).'),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(context, 'Weight: ${profile.weightLabel}'),
              _chip(context, '1.0h -> ${oneHour}g'),
              _chip(context, '2.5h -> ${twoHalfHours}g'),
              _chip(context, '4.0h -> ${fourHours}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuringCard(BuildContext context, _UserDefaultsProfile profile) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'During defaults (carb rate)'),
          const SizedBox(height: AppSpacing.xs),
          _line(context, 'Duration bands (g/hr):'),
          _line(context, '<60: 0-30, 60-90: 30-60, 90-150: 45-60'),
          _line(context, '150-240: 60-90, >240: 80-100'),
          const SizedBox(height: AppSpacing.xs),
          _line(
            context,
            'Then scale by gut training (${profile.gutMultiplierLabel}) and cap by sport: run 70, bike 120, swim 0.',
          ),
        ],
      ),
    );
  }

  Widget _buildScopeCard(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(context, 'When overrides apply'),
          const SizedBox(height: AppSpacing.xs),
          _line(
            context,
            'Pre and post overrides apply whenever those phases exist.',
          ),
          _line(
            context,
            'During overrides from this screen are applied only for workouts >= 90 minutes.',
          ),
          _line(
            context,
            'Brick workouts use the sport-specific run/bike/swim during overrides.',
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context) {
    return BaseCard(
      child: Text(
        'Source: generate-macros-v4 (`supabase/functions/generate-macros-v4/single-sport.ts`) '
        'plus the app-side >=90 minute during-override gate '
        '(`lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart`).',
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String value) {
    return Text(
      value,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _line(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        value,
        style: AppTextStyles.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  int _preWorkoutCarbs(double weightKg, double hoursBefore) {
    final carbsPerKg = hoursBefore.clamp(0.5, 4.0);
    return (weightKg * carbsPerKg).round();
  }
}

class _UserDefaultsProfile {
  const _UserDefaultsProfile({
    required this.weightKg,
    required this.weightLabel,
    required this.gutMultiplierLabel,
  });

  final double weightKg;
  final String weightLabel;
  final String gutMultiplierLabel;

  factory _UserDefaultsProfile.fromSettings(SettingsState? settingsState) {
    final weightLb = settingsState?.weightPounds;
    final hasWeight = weightLb != null && weightLb > 0;
    final weightKg = hasWeight ? weightLb * 0.45359237 : 70.0;

    final gut = settingsState?.gutTrainingLevel.name ?? 'moderate';
    final gutMultiplier = switch (gut) {
      'low' => 0.7,
      'high' => 1.2,
      _ => 1.0,
    };

    return _UserDefaultsProfile(
      weightKg: weightKg,
      weightLabel: hasWeight
          ? '${weightLb.toStringAsFixed(1)} lb (${weightKg.toStringAsFixed(1)} kg)'
          : 'Not set (using 70.0 kg)',
      gutMultiplierLabel: '${gutMultiplier.toStringAsFixed(1)}x',
    );
  }
}
