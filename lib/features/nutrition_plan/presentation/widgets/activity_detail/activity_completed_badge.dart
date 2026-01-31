import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity_completion.dart';
import '../../utils/activity_detail_helpers.dart';

/// Badge displayed when an activity has been completed
class ActivityCompletedBadge extends StatelessWidget {
  const ActivityCompletedBadge({
    super.key,
    this.completion,
  });

  final ActivityCompletion? completion;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(
              FontAwesomeIcons.circleCheck,
              size: AppIconSizes.xl,
              color: AppColors.electrolyte,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Workout Completed',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (completion?.completedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Completed on ${ActivityDetailHelpers.formatDate(completion!.completedAt)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
