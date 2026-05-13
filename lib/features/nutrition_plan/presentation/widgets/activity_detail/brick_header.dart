import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../activities/domain/brick_metadata.dart';
import '../../utils/activity_detail_helpers.dart';
import '../new_activity/brick/brick_composite_hero_image.dart';
import 'geometric_pattern_painter.dart';

/// BrickHeader widget - displays header for brick workout activities
///
/// Shows side-by-side sport icons, brick type name, combined distance/duration,
/// and scheduled date/time information.
class BrickHeader extends StatelessWidget {
  const BrickHeader({super.key, required this.brick, required this.metadata});

  final Activity brick;
  final BrickMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeroImageWithIcons(context),
        const SizedBox(height: AppSpacing.lg),
        _buildBrickInfo(context),
        const SizedBox(height: AppSpacing.lg),
        _buildScheduleInfo(context),
      ],
    );
  }

  /// Build hero image with geometric pattern and side-by-side sport images
  Widget _buildHeroImageWithIcons(BuildContext context) {
    // Build set of selected sports from metadata segments
    final selectedSports = metadata.segments.map((s) => s.sport).toSet();

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _buildGradient(),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, 280),
            painter: GeometricPatternPainter(),
          ),
          // Use the same BrickCompositeHeroImage widget as the new activity screen
          BrickCompositeHeroImage(selectedSports: selectedSports, height: 220),
        ],
      ),
    );
  }

  /// Build gradient with blended sport colors
  LinearGradient _buildGradient() {
    // Build color list from segment sports
    final colors = <Color>[];
    for (final segment in metadata.segments) {
      if (segment.sport == 'swimming') {
        colors.add(AppColors.electrolyte.withValues(alpha: 0.3));
      } else if (segment.sport == 'cycling') {
        colors.add(AppColors.orange.withValues(alpha: 0.3));
      } else if (segment.sport == 'running') {
        colors.add(AppColors.dragonfruit.withValues(alpha: 0.3));
      }
    }

    // If only one color, duplicate it for gradient
    if (colors.length == 1) {
      colors.add(colors[0]);
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  /// Build brick type name and summary info
  Widget _buildBrickInfo(BuildContext context) {
    return Column(
      children: [
        Text(
          _getBrickTypeName().toUpperCase(),
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.electrolyte,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _getDistanceSummary(),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Build scheduled date and time info
  Widget _buildScheduleInfo(BuildContext context) {
    final scheduledDateTime = brick.scheduledDateTime;

    return Column(
      children: [
        Text(
          ActivityDetailHelpers.formatDate(scheduledDateTime),
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ActivityDetailHelpers.formatTime(scheduledDateTime),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ' · ',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ActivityDetailHelpers.formatDuration(
                metadata.totalDurationMinutes,
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Get brick type name (e.g., "SWIM/RUN BRICK")
  String _getBrickTypeName() {
    final sports = metadata.segments.map((s) {
      switch (s.sport) {
        case 'swimming':
          return 'SWIM';
        case 'cycling':
          return 'BIKE';
        case 'running':
          return 'RUN';
        default:
          return s.sport.toUpperCase();
      }
    }).toList();

    return '${sports.join('/')} BRICK';
  }

  /// Get combined distance summary (e.g., "2000m swim + 6.2mi run")
  String _getDistanceSummary() {
    final parts = <String>[];

    for (final segment in metadata.segments) {
      final sportName = _getSportShortName(segment.sport);

      if (segment.sport == 'swimming' && segment.distanceMeters != null) {
        parts.add('${segment.distanceMeters!.toInt()}m $sportName');
      } else if (segment.distanceMiles != null) {
        parts.add('${segment.distanceMiles!.toStringAsFixed(1)}mi $sportName');
      } else {
        parts.add('${segment.durationMinutes}min $sportName');
      }
    }

    return parts.join(' + ');
  }

  /// Get short sport name for summary
  String _getSportShortName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'swim';
      case 'cycling':
        return 'bike';
      case 'running':
        return 'run';
      default:
        return sport;
    }
  }
}
