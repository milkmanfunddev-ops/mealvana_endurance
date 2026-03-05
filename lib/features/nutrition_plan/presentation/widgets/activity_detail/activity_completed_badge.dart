import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity_completion.dart';
import '../../utils/activity_detail_helpers.dart';

/// Rich card displayed when an activity has been completed.
/// Shows completion status, star rating, and editable notes.
class ActivityCompletedCard extends StatefulWidget {
  const ActivityCompletedCard({
    super.key,
    this.completion,
    this.rating,
    this.notes,
    required this.onRatingChanged,
    required this.onNotesChanged,
  });

  final ActivityCompletion? completion;
  final int? rating;
  final String? notes;
  final ValueChanged<int> onRatingChanged;
  final ValueChanged<String?> onNotesChanged;

  @override
  State<ActivityCompletedCard> createState() => _ActivityCompletedCardState();
}

class _ActivityCompletedCardState extends State<ActivityCompletedCard> {
  bool _isEditingNotes = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.notes ?? '');
  }

  @override
  void didUpdateWidget(ActivityCompletedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notes != oldWidget.notes && !_isEditingNotes) {
      _notesController.text = widget.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
          const SizedBox(height: AppSpacing.md),
          _buildNotesSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
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
            ActivityDetailHelpers.formatDate(
                widget.completion!.completedAt),
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
          return GestureDetector(
            onTap: () => widget.onRatingChanged(starIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: Icon(
                isFilled
                    ? FontAwesomeIcons.solidStar
                    : FontAwesomeIcons.star,
                size: 22,
                color: isFilled
                    ? AppColors.electrolyte
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    if (_isEditingNotes) {
      return _buildNotesEditor(context);
    }

    final hasNotes =
        widget.notes != null && widget.notes!.trim().isNotEmpty;

    return InkWell(
      onTap: () => setState(() => _isEditingNotes = true),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FontAwesomeIcons.noteSticky,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                hasNotes ? widget.notes! : 'Tap to add notes...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: hasNotes
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.6),
                  fontStyle:
                      hasNotes ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            Icon(
              FontAwesomeIcons.penToSquare,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _notesController,
          autofocus: true,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'Add your workout notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.sm),
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                _notesController.text = widget.notes ?? '';
                setState(() => _isEditingNotes = false);
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () {
                final text = _notesController.text.trim();
                widget.onNotesChanged(text.isEmpty ? null : text);
                setState(() => _isEditingNotes = false);
              },
              child: Text(
                'Save',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.electrolyte,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
