import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/activity.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import 'brick_segment_card.dart';

/// Brick group card widget
///
/// Displays a brick workout as a grouped card with header, subtitle,
/// and nested segment cards. The entire card is tappable for navigation.
/// Provides Ungroup, Delete, and Remove Segment actions.
///
/// Design Specs:
/// - Header background: Dark purple/navy (Blackberry)
/// - Chain link icon: Orange, 24px
/// - "BRICK" text: Orange, Compadre 14px
/// - Buttons: Orange outline, 12px text
/// - Subtitle: Gray text, Apercu 12px
/// - Nested segment cards: Slightly lighter background
class BrickGroupCard extends StatelessWidget {
  const BrickGroupCard({
    super.key,
    required this.brick,
    required this.onUngroup,
    required this.onViewCombined,
    required this.onRemoveSegment,
    required this.onDelete,
  });

  final Activity brick;
  final VoidCallback onUngroup;
  final VoidCallback onViewCombined;
  final Function(int segmentIndex) onRemoveSegment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build semantic label for the brick workout
    final segments = brick.brickMetadata?.segments ?? [];
    final sportNames = segments.map((s) => s.sport).join(' and ');
    final semanticLabel = 'Brick workout containing $sportNames';

    return Semantics(
      label: semanticLabel,
      container: true,
      child: InkWell(
        onTap: onViewCombined,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.blackberryLight : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (isDark ? AppColors.cream : AppColors.blackberry)
                  .withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, isDark),
              // _buildSubtitle(isDark),
              _buildSegments(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // color: AppColors.blackberryDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        children: [
          // Chain link icon (decorative, exclude from semantics)
          ExcludeSemantics(
            child: Icon(
              FontAwesomeIcons.link,
              color: AppColors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),

          // "BRICK" text
          const Expanded(
            child: Text(
              'BRICK',
              style: TextStyle(
                fontFamily: 'Compadre',
                fontSize: 14,
                color: AppColors.orange,
                height: 1.3,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Delete brick workout',
                button: true,
                child: SizedBox(
                  height: 44, // Ensure minimum touch target height
                  child: IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Ungroup brick into separate activities',
                button: true,
                child: SizedBox(
                  height: 44, // Ensure minimum touch target height
                  child: KyleSecondaryButtonSmall(
                    text: 'Ungroup',
                    onPressed: onUngroup,
                    variant: SecondaryButtonVariant.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegments() {
    // Get segments from brick metadata
    final segments = brick.brickMetadata?.segments ?? [];

    if (segments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No segments found',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 12,
            color: AppColors.inactive,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: segments.asMap().entries.map((entry) {
          final index = entry.key;
          final segment = entry.value;

          return BrickSegmentCard(
            segment: segment,
            order: segment.order,
            onRemove: () => onRemoveSegment(index),
            showRemoveButton: segments.length > 2, // Only show X if 3+ segments
          );
        }).toList(),
      ),
    );
  }
}
