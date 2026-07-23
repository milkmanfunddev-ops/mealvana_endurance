import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity_completion.dart';
import '../../../domain/carb_adjustment_level.dart';
import '../../utils/activity_detail_helpers.dart';

/// Rich card displayed when an activity has been completed.
/// Shows completion status, star rating, and editable notes.
class ActivityCompletedCard extends StatefulWidget {
  const ActivityCompletedCard({
    super.key,
    this.completion,
    this.rating,
    this.carbAdjustment,
    this.notes,
    required this.onRatingChanged,
    required this.onNotesChanged,
  });

  final ActivityCompletion? completion;
  final int? rating;
  final CarbAdjustmentLevel? carbAdjustment;
  final String? notes;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String?> onNotesChanged;

  @override
  State<ActivityCompletedCard> createState() => _ActivityCompletedCardState();
}

class _ActivityCompletedCardState extends State<ActivityCompletedCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: AppSpacing.md),
          _buildRatingRow(context),
          if (widget.carbAdjustment != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildCarbFeedbackRow(context),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildNotesSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        FaIcon(
          FontAwesomeIcons.circleCheck,
          size: AppIconSizes.md,
          color: AppColors.electrolyte,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Workout Completed',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (widget.completion?.completedAt != null)
          Text(
            ActivityDetailHelpers.formatDate(widget.completion!.completedAt),
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildRatingRow(BuildContext context) {
    final currentRating = widget.rating ?? 0;

    return Row(
      children: [
        Text(
          'Rating',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ...List.generate(5, (index) {
          final starIndex = index + 1;
          final isFilled = starIndex <= currentRating;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Icon(
              isFilled
                  ? FontAwesomeIcons.solidStar.data
                  : FontAwesomeIcons.star.data,
              size: 22,
              color: isFilled
                  ? AppColors.electrolyte
                  : Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCarbFeedbackRow(BuildContext context) {
    final adjustment = widget.carbAdjustment!;
    return Row(
      children: [
        Text(
          'Carbs',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${adjustment.emoji} ${adjustment.label}',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final hasNotes = widget.notes != null && widget.notes!.trim().isNotEmpty;
    if (!hasNotes) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(
            FontAwesomeIcons.noteSticky,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.notes!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
