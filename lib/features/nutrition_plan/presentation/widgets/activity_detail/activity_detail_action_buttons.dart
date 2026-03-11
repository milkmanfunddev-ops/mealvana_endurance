import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../providers/activity_detail_state.dart';
import 'activity_completed_badge.dart';
import 'post_workout_feedback_dialog.dart';
import 'brick_completion_dialog.dart';
import '../../../domain/carb_adjustment_level.dart';

/// Action buttons section for ActivityDetailScreen (Save, Complete, or Completed state)
class ActivityDetailActionButtons extends StatelessWidget {
  const ActivityDetailActionButtons({
    super.key,
    required this.state,
    required this.isNewActivity,
    required this.isCoachView,
    required this.onSave,
    required this.onComplete,
    required this.onRatingChanged,
    required this.onNotesChanged,
  });

  final ActivityDetailState state;
  final bool isNewActivity;
  final bool isCoachView;
  final VoidCallback onSave;
  final void Function(int rating, String? notes, {bool isBrick, CarbAdjustmentLevel? carbAdjustment}) onComplete;
  final void Function(int rating) onRatingChanged;
  final void Function(String? notes) onNotesChanged;

  @override
  Widget build(BuildContext context) {
    if (state.isCompleted) {
      return ActivityCompletedCard(
        completion: state.completion,
        rating: state.activity?.completionRating,
        notes: state.activity?.completionNotes,
        onRatingChanged: onRatingChanged,
        onNotesChanged: onNotesChanged,
      );
    }

    // Coach view: Only show Save button (for saving feedback/notes)
    if (isCoachView) {
      return KylePrimaryButton(
        text: state.isSaving ? 'Saving...' : 'Save',
        onPressed: state.isSaving ? null : onSave,
      );
    }

    if (isNewActivity) {
      return KylePrimaryButton(
        text: state.isSaving ? 'Saving...' : 'Save Workout',
        onPressed: state.isSaving ? null : onSave,
      );
    }

    return Row(
      children: [
        Expanded(
          child: KyleSecondaryButton(
            text: state.isSaving ? 'Saving...' : 'Save',
            onPressed: state.isSaving ? null : onSave,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: KylePrimaryButton(
            text: state.isCompleting ? 'Completing...' : 'Complete',
            onPressed: state.isCompleting ? null : () => _handleComplete(context),
          ),
        ),
      ],
    );
  }

  void _handleComplete(BuildContext context) {
    final activity = state.activity;
    final isBrick = activity != null && activity.isBrick;

    showDialog(
      context: context,
      builder: (dialogContext) {
        // Use brick-specific dialog if this is a brick workout
        if (isBrick && activity.brickMetadata != null) {
          return BrickCompletionDialog(
            brick: activity,
            onComplete: (rating, notes) async {
              Navigator.of(dialogContext).pop();
              onComplete(rating, notes, isBrick: true);
            },
          );
        }

        // Compute during-activity carb rate for feedback section
        double? duringCarbRateGPerH;
        if (state.nutritionPlan != null) {
          final duringSection = state.nutritionPlan!.sections
              .where((s) => s.id.contains('during'))
              .firstOrNull;
          final durationMinutes = activity?.durationMinutes?.toDouble();
          if (duringSection?.carbsTarget != null &&
              durationMinutes != null &&
              durationMinutes > 0) {
            duringCarbRateGPerH =
                duringSection!.carbsTarget! / (durationMinutes / 60.0);
          }
        }

        // Use post-workout feedback dialog for single-sport workouts
        return PostWorkoutFeedbackDialog(
          duringCarbRateGPerH: duringCarbRateGPerH,
          onComplete: (rating, notes, carbAdjustment) async {
            Navigator.of(dialogContext).pop();
            onComplete(rating, notes, isBrick: false, carbAdjustment: carbAdjustment);
          },
        );
      },
    );
  }
}
