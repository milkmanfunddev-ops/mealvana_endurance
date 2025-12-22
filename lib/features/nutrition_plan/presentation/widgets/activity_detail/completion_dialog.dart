import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Workout Completion Dialog
/// Allows user to rate workout and add optional notes
class CompletionDialog extends StatefulWidget {
  const CompletionDialog({
    super.key,
    required this.onComplete,
  });

  final Function(int rating, String? notes) onComplete;

  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog> {
  int _rating = 3;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
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

            const SizedBox(height: AppSpacing.lg),

            // Success message
            Text(
              'Complete Workout',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Rating
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
                    rating <= _rating ? FontAwesomeIcons.solidStar : FontAwesomeIcons.star,
                    color: AppColors.orange,
                    size: AppIconSizes.md,
                  ),
                  onPressed: () => setState(() => _rating = rating),
                );
              }),
            ),

            const SizedBox(height: AppSpacing.md),

            // Notes field
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputRadius,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Complete button
            KylePrimaryButton(
              text: 'Complete',
              onPressed: () {
                widget.onComplete(
                  _rating,
                  _notesController.text.isEmpty ? null : _notesController.text,
                );
              },
            ),

            const SizedBox(height: AppSpacing.sm),

            // Cancel button
            KyleTertiaryButton(
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
