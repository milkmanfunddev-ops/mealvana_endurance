import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/carb_adjustment_level.dart';
import 'carb_feedback_selector.dart';

/// Post-workout feedback dialog replacing the simple CompletionDialog.
///
/// Collects:
/// 1. Star rating (1-5)
/// 2. Optional notes
/// 3. Carb adjustment feedback (only shown when [duringCarbRateGPerH] is provided)
class PostWorkoutFeedbackDialog extends StatefulWidget {
  const PostWorkoutFeedbackDialog({
    super.key,
    required this.onComplete,
    this.duringCarbRateGPerH,
    this.initialRating,
    this.initialNotes,
    this.initialCarbAdjustment,
    this.isEditMode = false,
  });

  /// Callback when user completes feedback.
  final void Function(
    int rating,
    String? notes,
    CarbAdjustmentLevel? carbAdjustment,
  )
  onComplete;

  /// The during-activity carb rate from the nutrition plan.
  /// When null, the carb feedback section is hidden (no nutrition plan).
  final double? duringCarbRateGPerH;
  final int? initialRating;
  final String? initialNotes;
  final CarbAdjustmentLevel? initialCarbAdjustment;
  final bool isEditMode;

  @override
  State<PostWorkoutFeedbackDialog> createState() =>
      _PostWorkoutFeedbackDialogState();
}

class _PostWorkoutFeedbackDialogState extends State<PostWorkoutFeedbackDialog> {
  late int _rating;
  late final TextEditingController _notesController;
  CarbAdjustmentLevel? _carbAdjustment;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 3;
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _carbAdjustment = widget.initialCarbAdjustment;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showCarbSection =
        widget.duringCarbRateGPerH != null && widget.duringCarbRateGPerH! > 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: AppSpacing.lg),
              _buildRatingSection(context),
              const SizedBox(height: AppSpacing.md),
              _buildNotesField(context),
              if (showCarbSection) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildCarbFeedbackSection(context),
              ],
              const SizedBox(height: AppSpacing.lg),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.electrolyte.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            FontAwesomeIcons.check,
            size: AppIconSizes.xl,
            color: AppColors.electrolyte,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          widget.isEditMode ? 'Edit Workout Feedback' : 'Workout Complete!',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'How did it go?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return IconButton(
              icon: Icon(
                rating <= _rating
                    ? FontAwesomeIcons.solidStar
                    : FontAwesomeIcons.star,
                color: AppColors.orange,
                size: AppIconSizes.md,
              ),
              onPressed: () => setState(() => _rating = rating),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Add notes (optional)',
        border: OutlineInputBorder(borderRadius: AppRadius.inputRadius),
      ),
    );
  }

  Widget _buildCarbFeedbackSection(BuildContext context) {
    final rate = widget.duringCarbRateGPerH!.round();

    return Column(
      children: [
        Divider(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'How did the carbs feel?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'You consumed ~${rate}g/hr',
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CarbFeedbackSelector(
          selectedLevel: _carbAdjustment,
          onLevelSelected: (level) => setState(() => _carbAdjustment = level),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        KylePrimaryButton(
          text: widget.isEditMode ? 'Save Changes' : 'Complete',
          onPressed: () {
            widget.onComplete(
              _rating,
              _notesController.text.isEmpty ? null : _notesController.text,
              _carbAdjustment,
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        KyleTertiaryButton(
          text: widget.isEditMode ? 'Cancel' : 'Skip',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
