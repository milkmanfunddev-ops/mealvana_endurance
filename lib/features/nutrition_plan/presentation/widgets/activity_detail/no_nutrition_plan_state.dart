import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';

/// Widget shown when no nutrition plan exists - displays empty state with generate button
class NoNutritionPlanState extends StatelessWidget {
  const NoNutritionPlanState({
    super.key,
    required this.activity,
    required this.onGeneratePlan,
  });

  final Activity? activity;
  final VoidCallback onGeneratePlan;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              FaIcon(
                FontAwesomeIcons.utensils,
                size: AppIconSizes.xl,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No nutrition plan yet',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Generate a nutrition plan to see recommendations',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Generate Plan Button
              KylePrimaryButton(
                onPressed: onGeneratePlan,
                text: 'Generate Plan',
                icon: FontAwesomeIcons.wandMagicSparkles.data,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
