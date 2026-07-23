import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../../shared/widgets/content_area.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../integrations/presentation/widgets/garmin_attribution.dart';

/// Shown on the fuel-log screen when the activity has no nutrition plan.
///
/// Garmin pushes auto-create a completed activity for endurance workouts
/// even when no plan was ever generated, and the activity-upload notification
/// routes the user here. Without a plan there are no fuel sections to fill,
/// so we explain the situation and offer two paths: generate a plan now, or
/// just close out (the activity itself is already marked completed by Garmin).
class FuelLogNoPlanState extends StatelessWidget {
  const FuelLogNoPlanState({
    super.key,
    required this.activity,
    required this.onGeneratePlan,
    required this.onClose,
  });

  final Activity activity;
  final VoidCallback onGeneratePlan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasGarminData = activity.hasGarminData;

    return ContentArea(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPaddingHorizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            BaseCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.utensils,
                      size: AppIconSizes.xxl,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No fueling plan for this workout',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _bodyCopy(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    KylePrimaryButton(
                      onPressed: onGeneratePlan,
                      text: 'Generate fueling plan',
                      icon: FontAwesomeIcons.wandMagicSparkles.data,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: onClose,
                      child: Text(
                        'Close',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasGarminData) ...[
                      const SizedBox(height: AppSpacing.md),
                      // Garmin Developer API Brand Guidelines require
                      // attribution wherever Garmin-derived data appears.
                      GarminAttribution(
                        deviceName: activity.garminDeviceName,
                        style: GarminAttributionStyle.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  String _bodyCopy() {
    if (activity.hasGarminData) {
      return 'This workout came in from Garmin without a nutrition plan. '
          'Generate one to start logging what you ate and drank during it.';
    }
    return 'There is no nutrition plan attached to this workout yet. '
        'Generate one to start logging what you ate and drank during it.';
  }
}
