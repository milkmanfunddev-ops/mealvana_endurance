import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/carb_adjustment_level.dart';

/// Feedback section at the bottom of fuel log: star rating, carb emoji, and notes.
class FuelLogFeedbackSection extends StatefulWidget {
  const FuelLogFeedbackSection({
    super.key,
    this.initialRating,
    this.initialNutritionRating,
    this.initialNotes,
    this.duringCarbRateGPerH,
    required this.onRatingChanged,
    required this.onNutritionRatingChanged,
    required this.onNotesChanged,
  });

  final int? initialRating;
  final int? initialNutritionRating;
  final String? initialNotes;
  final double? duringCarbRateGPerH;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<int?> onNutritionRatingChanged;
  final ValueChanged<String?> onNotesChanged;

  @override
  State<FuelLogFeedbackSection> createState() => _FuelLogFeedbackSectionState();
}

class _FuelLogFeedbackSectionState extends State<FuelLogFeedbackSection> {
  late int _rating;
  CarbAdjustmentLevel? _carbAdjustment;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0;
    _carbAdjustment = CarbAdjustmentLevel.fromRatingValue(
      widget.initialNutritionRating,
    );
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'How did it go?',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Star rating
          _buildStarRating(context),
          const SizedBox(height: AppSpacing.lg),

          // Carb feedback (only shown if activity has during-section carb rate)
          if (widget.duringCarbRateGPerH != null) ...[
            _buildCarbFeedback(context),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Notes
          _buildNotesField(context),
        ],
      ),
    );
  }

  Widget _buildStarRating(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overall Rating',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= _rating;
            return GestureDetector(
              onTap: () {
                setState(() => _rating = starValue);
                widget.onRatingChanged(starValue);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isSelected
                      ? AppColors.orange
                      : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                  size: 36,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCarbFeedback(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How did the carbs feel?',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (widget.duringCarbRateGPerH != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${widget.duringCarbRateGPerH!.round()}g carbs/hr',
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Wrap(
          spacing: AppSpacing.xs,
          children: CarbAdjustmentLevel.values.map((level) {
            final isSelected = _carbAdjustment == level;
            return GestureDetector(
              onTap: () {
                setState(() => _carbAdjustment = level);
                widget.onNutritionRatingChanged(level.ratingValue);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.smRadius,
                  color: isSelected
                      ? AppColors.orange.withValues(alpha: 0.15)
                      : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.05),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.orange
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(level.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(
                      level.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (optional)',
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'How did the nutrition feel? Any GI issues?',
            hintStyle: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
              ),
            ),
            contentPadding: AppSpacing.inputPadding,
          ),
          onChanged: widget.onNotesChanged,
        ),
      ],
    );
  }
}
