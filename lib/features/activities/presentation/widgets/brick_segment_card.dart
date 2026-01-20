import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/brick_metadata.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';

/// Brick segment card widget
///
/// Displays a single segment within a brick workout with sport icon,
/// distance/duration details, and optional remove button.
///
/// Design Specs:
/// - Background: Slightly lighter than parent brick card
/// - Sport icon: 24px, Electrolyte color
/// - Title: Compadre 14px
/// - Details: Apercu 12px, secondary color
/// - Remove button: Orange outline circle, 32px
class BrickSegmentCard extends StatelessWidget {
  const BrickSegmentCard({
    super.key,
    required this.segment,
    required this.order,
    this.onRemove,
    this.showRemoveButton = true,
  });

  final BrickSegment segment;
  final int order;
  final VoidCallback? onRemove;
  final bool showRemoveButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blackberry.withValues(alpha: 0.5)
            : AppColors.cream.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.cream : AppColors.blackberry)
              .withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _buildSportIcon(),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSegmentDetails(context, isDark),
            ),
            if (showRemoveButton && onRemove != null)
              _buildRemoveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSportIcon() {
    return Icon(
      _getIconForSport(segment.sport),
      color: AppColors.electrolyte,
      size: 24,
    );
  }

  Widget _buildSegmentDetails(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getSegmentTitle(),
          style: TextStyle(
            fontFamily: 'Compadre',
            fontSize: 14,
            color: isDark ? AppColors.cream : AppColors.blackberry,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          _getSegmentDetails(),
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 12,
            color: (isDark ? AppColors.cream : AppColors.blackberry)
                .withValues(alpha: 0.7),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return KyleSecondaryIconButton(
      icon: FontAwesomeIcons.xmark,
      onPressed: onRemove!,
      size: 32,
      variant: SecondaryButtonVariant.orange,
    );
  }

  IconData _getIconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'swimming':
        return FontAwesomeIcons.personSwimming;
      case 'cycling':
        return FontAwesomeIcons.personBiking;
      case 'running':
        return FontAwesomeIcons.personRunning;
      default:
        return FontAwesomeIcons.personRunning;
    }
  }

  String _getSegmentTitle() {
    final sportName = segment.sport.toUpperCase();

    // Format distance/duration based on sport
    if (segment.sport.toLowerCase() == 'swimming') {
      if (segment.distanceMeters != null) {
        return '$sportName ${_formatSwimmingDistance(segment.distanceMeters!)}';
      }
    } else if (segment.distanceMiles != null) {
      return '$sportName ${segment.distanceMiles!.toStringAsFixed(1)} MI';
    }

    // Fallback to duration if distance not available
    if (segment.durationMinutes > 0) {
      return '$sportName ${segment.durationMinutes} MIN';
    }

    return sportName;
  }

  String _getSegmentDetails() {
    final details = <String>[];

    if (segment.sport.toLowerCase() == 'swimming') {
      // Swimming: distance · pace
      if (segment.distanceMeters != null) {
        details.add('${segment.distanceMeters!.toInt()}m');
      }
      if (segment.pacePer100mSeconds != null) {
        details.add(_formatSwimmingPace(segment.pacePer100mSeconds!));
      }
    } else {
      // Cycling/Running: distance · pace/speed
      if (segment.distanceMiles != null) {
        details.add('${segment.distanceMiles!.toStringAsFixed(1)} mi');
      }

      if (segment.sport.toLowerCase() == 'cycling' && segment.speedMph != null) {
        details.add('${segment.speedMph!.toStringAsFixed(1)} mph');
      } else if (segment.sport.toLowerCase() == 'running' && segment.paceMinutesPerMile != null) {
        details.add(_formatRunningPace(segment.paceMinutesPerMile!));
      }
    }

    return details.join(' · ');
  }

  String _formatSwimmingDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}K M';
    }
    return '${meters.toInt()} M';
  }

  String _formatSwimmingPace(int secondsPer100m) {
    final minutes = secondsPer100m ~/ 60;
    final seconds = secondsPer100m % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/100m';
  }

  String _formatRunningPace(double minutesPerMile) {
    final minutes = minutesPerMile.floor();
    final seconds = ((minutesPerMile - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/mi';
  }
}
