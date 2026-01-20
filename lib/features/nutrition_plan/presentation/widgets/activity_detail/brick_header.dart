import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../activities/domain/activity.dart';
import '../../../../activities/domain/brick_metadata.dart';
import 'geometric_pattern_painter.dart';

/// BrickHeader widget - displays header for brick workout activities
///
/// Shows side-by-side sport icons, brick type name, combined distance/duration,
/// and scheduled date/time information.
class BrickHeader extends StatelessWidget {
  const BrickHeader({
    super.key,
    required this.brick,
    required this.metadata,
  });

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

  /// Build hero image with geometric pattern and side-by-side sport icons
  Widget _buildHeroImageWithIcons(BuildContext context) {
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
          _buildSportIcons(context),
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

  /// Build side-by-side sport icons with dividers
  Widget _buildSportIcons(BuildContext context) {
    final icons = <Widget>[];

    for (var i = 0; i < metadata.segments.length; i++) {
      final segment = metadata.segments[i];

      // Add sport icon
      icons.add(_getSportIcon(segment.sport));

      // Add divider between icons (but not after last one)
      if (i < metadata.segments.length - 1) {
        icons.add(Container(
          width: 1,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          color: AppColors.cream.withValues(alpha: 0.3),
        ));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: icons,
    );
  }

  /// Get icon widget for sport type
  Widget _getSportIcon(String sport) {
    IconData iconData;
    Color iconColor;

    switch (sport) {
      case 'swimming':
        iconData = FontAwesomeIcons.personSwimming;
        iconColor = AppColors.electrolyte;
        break;
      case 'cycling':
        iconData = FontAwesomeIcons.personBiking;
        iconColor = AppColors.orange;
        break;
      case 'running':
        iconData = FontAwesomeIcons.personRunning;
        iconColor = AppColors.dragonfruit;
        break;
      default:
        iconData = FontAwesomeIcons.question;
        iconColor = AppColors.cream;
    }

    return Icon(
      iconData,
      size: 48,
      color: iconColor,
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
          _formatDate(scheduledDateTime),
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
              _formatTime(scheduledDateTime),
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
              '${metadata.totalDurationMinutes} minutes',
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

  /// Format date as "Saturday, January 19, 2026"
  String _formatDate(DateTime date) {
    final weekday = _getWeekdayName(date.weekday);
    final month = _getMonthName(date.month);
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  /// Format time as "8:00 AM"
  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }
}
