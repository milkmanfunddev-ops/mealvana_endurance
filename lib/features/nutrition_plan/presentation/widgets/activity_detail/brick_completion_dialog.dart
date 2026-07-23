import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../activities/domain/brick_metadata.dart';

/// Brick Workout Completion Dialog
/// Allows user to rate brick workout and add optional notes
/// Shows segment summary for better context
class BrickCompletionDialog extends StatefulWidget {
  const BrickCompletionDialog({
    super.key,
    required this.brick,
    required this.onComplete,
  });

  final Activity brick;
  final Function(int rating, String? notes) onComplete;

  @override
  State<BrickCompletionDialog> createState() => _BrickCompletionDialogState();
}

class _BrickCompletionDialogState extends State<BrickCompletionDialog> {
  int _rating = 3;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.brick.brickMetadata;
    final segments = metadata?.segments ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon with chain link
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  FontAwesomeIcons.link,
                  size: AppIconSizes.xl,
                  color: AppColors.orange,
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Success message
              Text(
                'Complete Brick Workout',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Segment summary
              if (segments.isNotEmpty) ...[
                Text(
                  _buildSegmentSummary(segments),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

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
                      rating <= _rating
                          ? FontAwesomeIcons.solidStar.data
                          : FontAwesomeIcons.star.data,
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
                text: 'Complete Brick',
                onPressed: () {
                  widget.onComplete(
                    _rating,
                    _notesController.text.isEmpty
                        ? null
                        : _notesController.text,
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
      ),
    );
  }

  /// Build a human-readable segment summary
  /// Example: "Swim 2000m + Bike 25.0mi + Run 6.2mi"
  String _buildSegmentSummary(List<BrickSegment> segments) {
    final parts = segments.map((segment) {
      final sportName = _getSportName(segment.sport);
      final distance = _formatDistance(segment);
      return '$sportName $distance';
    }).toList();

    return parts.join(' + ');
  }

  String _getSportName(String sport) {
    switch (sport.toLowerCase()) {
      case 'swimming':
        return 'Swim';
      case 'cycling':
        return 'Bike';
      case 'running':
        return 'Run';
      default:
        return sport;
    }
  }

  String _formatDistance(BrickSegment segment) {
    final sport = segment.sport.toLowerCase();
    if (sport == 'swimming' && segment.distanceMeters != null) {
      return '${segment.distanceMeters}m';
    } else if ((sport == 'cycling' || sport == 'running') &&
        segment.distanceMiles != null) {
      return '${segment.distanceMiles!.toStringAsFixed(1)}mi';
    }
    return '';
  }
}
