import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/brick_metadata.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
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
class BrickSegmentCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    // Build semantic label for the segment
    final sportName = segment.sport;
    final distanceInfo = _getSegmentDetails(useMetric);
    final semanticLabel = '$sportName segment, $distanceInfo, position $order';

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.blackberry.withValues(alpha: 0.5)
              : AppColors.cream.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
              alpha: 0.1,
            ),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildSportIcon(),
              const SizedBox(width: 10),
              Expanded(child: _buildSegmentDetails(context, isDark, useMetric)),
              if (showRemoveButton && onRemove != null) _buildRemoveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportIcon() {
    // Sport icon is decorative, exclude from semantics
    return ExcludeSemantics(
      child: Icon(
        _getIconForSport(segment.sport),
        color: AppColors.electrolyte,
        size: 24,
      ),
    );
  }

  Widget _buildSegmentDetails(
    BuildContext context,
    bool isDark,
    bool useMetric,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getSegmentTitle(useMetric),
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
          _getSegmentDetails(useMetric),
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 12,
            color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
              alpha: 0.7,
            ),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return Semantics(
      label: 'Remove ${segment.sport} from brick',
      button: true,
      child: SizedBox(
        width: 44, // Ensure minimum touch target size
        height: 44, // Ensure minimum touch target size
        child: Center(
          child: KyleSecondaryIconButton(
            icon: FontAwesomeIcons.xmark.data,
            onPressed: onRemove!,
            size: 32, // Visual size (icon stays 32px)
            variant: SecondaryButtonVariant.orange,
          ),
        ),
      ),
    );
  }

  IconData _getIconForSport(String sport) {
    switch (sport.toLowerCase()) {
      case 'swimming':
        return FontAwesomeIcons.personSwimming.data;
      case 'cycling':
        return FontAwesomeIcons.personBiking.data;
      case 'running':
        return FontAwesomeIcons.personRunning.data;
      default:
        return FontAwesomeIcons.personRunning.data;
    }
  }

  String _getSegmentTitle(bool useMetric) {
    final sportName = segment.sport.toUpperCase();
    final distanceUnit = useMetric
        ? DistanceUnit.kilometers
        : DistanceUnit.miles;

    // Format distance/duration based on sport
    if (segment.sport.toLowerCase() == 'swimming') {
      if (segment.distanceMeters != null) {
        return '$sportName ${_formatSwimmingDistance(segment.distanceMeters!)}';
      }
    } else if (segment.distanceMiles != null) {
      final distanceText = UnitFormatter.formatDistance(
        segment.distanceMiles!,
        unit: distanceUnit,
      ).toUpperCase();
      return '$sportName $distanceText';
    }

    // Fallback to duration if distance not available
    if (segment.durationMinutes > 0) {
      return '$sportName ${segment.durationMinutes} MIN';
    }

    return sportName;
  }

  String _getSegmentDetails(bool useMetric) {
    final details = <String>[];
    final distanceUnit = useMetric
        ? DistanceUnit.kilometers
        : DistanceUnit.miles;
    final paceUnit = useMetric ? PaceUnit.minPerKm : PaceUnit.minPerMile;

    if (segment.sport.toLowerCase() == 'swimming') {
      // Swimming: distance · pace (pool-length convention, always meters -
      // not an imperial/metric split)
      if (segment.distanceMeters != null) {
        details.add('${segment.distanceMeters!.toInt()}m');
      }
      if (segment.pacePer100mSeconds != null) {
        details.add(_formatSwimmingPace(segment.pacePer100mSeconds!));
      }
    } else {
      // Cycling/Running: distance · pace/speed
      if (segment.distanceMiles != null) {
        details.add(
          UnitFormatter.formatDistance(
            segment.distanceMiles!,
            unit: distanceUnit,
          ),
        );
      }

      if (segment.sport.toLowerCase() == 'cycling' &&
          segment.speedMph != null) {
        details.add(
          UnitFormatter.formatSpeed(segment.speedMph!, useMetric: useMetric),
        );
      } else if (segment.sport.toLowerCase() == 'running' &&
          segment.paceMinutesPerMile != null) {
        details.add(
          UnitFormatter.formatPace(segment.paceMinutesPerMile!, unit: paceUnit),
        );
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
}
