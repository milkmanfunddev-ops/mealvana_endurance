import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/brick_metadata.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../fuel_timeline_type.dart';

/// A created brick, rendered *inside* the timeline instead of extruding out of
/// it.
///
/// This is the fix for problem A in the brick redesign (Notion 3a7e3fdb):
/// the old [BrickGroupCard] spanned the full row width — including the left
/// rail — so the vertical timeline line was severed at the brick. Here the
/// brick keeps the ordinary tile geometry (time label · rail · card), takes a
/// single time-dot like any other row, and its legs live in an **indented
/// bracket** hanging off the brick card:
///
/// ```
///  1:30 PM  ●  ⛓ BRICK   2 legs · 148 min          ···
///           │  ┃ ① 🏃 12 MI RUN            108 min
///           │  ┃ ② 🏊 2000 M SWIM           40 min
///           │  Pre · During · Recovery fuel
/// ```
///
/// "The legs stay visible inside an indented bracket; tap one for its fuel
/// detail." (prototype step 3, quoted in Notion.)
class TimelineBrickTile extends ConsumerWidget {
  const TimelineBrickTile({
    super.key,
    required this.brick,
    required this.timelineOpen,
    required this.onOpenBrick,
    required this.onOpenLeg,
    required this.onUngroup,
    required this.onDelete,
  });

  final Activity brick;
  final bool timelineOpen;

  /// Tap the brick header → the combined brick fuel plan.
  final VoidCallback onOpenBrick;

  /// Tap a leg → that leg's fuel detail. Receives the 0-based leg index.
  final void Function(int legIndex) onOpenLeg;

  final VoidCallback onUngroup;
  final VoidCallback onDelete;

  static final _timeFmt = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final surfaceBg = isDark ? AppColors.blackberry : AppColors.cream;
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (timelineOpen) ...[
            SizedBox(
              width: 54,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    _timeFmt.format(brick.scheduledDateTime),
                    textAlign: TextAlign.right,
                    style: FtType.macroLine.copyWith(
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _rail(onSurface, surfaceBg),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: _brickCard(context, onSurface, useMetric),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The ordinary timeline rail with exactly one dot — the brick is one entry
  /// on the line, not a break in it.
  Widget _rail(Color onSurface, Color surfaceBg) {
    return SizedBox(
      width: 16,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: onSurface.withValues(alpha: 0.22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange,
                border: Border.all(color: surfaceBg, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brickCard(BuildContext context, Color onSurface, bool useMetric) {
    final segments = brick.brickMetadata?.segments ?? const <BrickSegment>[];

    return Semantics(
      container: true,
      label:
          'Brick workout containing ${segments.map((s) => s.sport).join(' and ')}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(context, onSurface, segments),
            _bracket(context, onSurface, segments, useMetric),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Color onSurface,
    List<BrickSegment> segments,
  ) {
    final total = brick.brickMetadata?.totalDurationMinutes ?? 0;
    final parts = <String>[
      '${segments.length} leg${segments.length == 1 ? '' : 's'}',
      if (total > 0) '$total min',
    ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenBrick,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.link, size: 14, color: AppColors.orange),
            ),
            const SizedBox(width: 6),
            Text(
              'BRICK',
              style: FtType.itemName.copyWith(color: AppColors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FtType.macroLine.copyWith(
                  fontWeight: FontWeight.w400,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
            _menu(context, onSurface),
          ],
        ),
      ),
    );
  }

  /// `ungroup legs` / `delete brick` return to the ungrouped state
  /// (Notion 3a7e3fdb — "Rules that fall out").
  Widget _menu(BuildContext context, Color onSurface) {
    return Semantics(
      label: 'Brick actions',
      button: true,
      child: PopupMenuButton<String>(
        key: const ValueKey('fuel_timeline.brick_menu'),
        icon: Icon(
          Icons.more_horiz,
          size: 20,
          color: onSurface.withValues(alpha: 0.6),
        ),
        padding: EdgeInsets.zero,
        tooltip: 'Brick actions',
        onSelected: (value) {
          if (value == 'ungroup') onUngroup();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'ungroup', child: Text('Ungroup legs')),
          PopupMenuItem(value: 'delete', child: Text('Delete brick')),
        ],
      ),
    );
  }

  /// The indented bracket: one orange spine with a stub into each leg, so the
  /// legs read as belonging to the brick without breaking the outer rail.
  Widget _bracket(
    BuildContext context,
    Color onSurface,
    List<BrickSegment> segments,
    bool useMetric,
  ) {
    if (segments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The bracket: one orange spine down the left of the leg stack, so
          // the legs read as nested inside the brick without the outer rail
          // ever being interrupted.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _leg(
                          context,
                          onSurface,
                          segments[i],
                          i,
                          useMetric: useMetric,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Pre · During · Recovery fuel',
            style: FtType.macroLine.copyWith(color: AppColors.orange),
          ),
        ],
      ),
    );
  }

  /// One leg, as its own sub-card: circled leg number, sport icon, name, and
  /// the duration right-aligned. "Tap one for its fuel detail."
  Widget _leg(
    BuildContext context,
    Color onSurface,
    BrickSegment segment,
    int index, {
    required bool useMetric,
  }) {
    final subtitle = _legSubtitle(segment, useMetric);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpenLeg(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.orange, width: 1.2),
              ),
              child: Text(
                '${index + 1}',
                style: FtType.macroLine.copyWith(
                  fontSize: 9.5,
                  height: 1.0,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Icon(
              _sportIcon(segment.sport),
              size: 14,
              color: AppColors.electrolyteDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _sportLabel(segment.sport).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FtType.itemName.copyWith(color: onSurface),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: FtType.macroLine.copyWith(
                  fontWeight: FontWeight.w400,
                  color: onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _legSubtitle(BrickSegment segment, bool useMetric) {
    final parts = <String>[];
    if (segment.distanceMeters != null) {
      parts.add('${segment.distanceMeters!.round()} m');
    } else if (segment.distanceMiles != null) {
      parts.add(
        UnitFormatter.formatDistance(
          segment.distanceMiles!,
          unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
        ),
      );
    }
    if (segment.durationMinutes > 0) {
      parts.add('${segment.durationMinutes} min');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _sportLabel(String sport) {
    return switch (sport) {
      'swimming' => 'Swim',
      'cycling' => 'Bike',
      'running' => 'Run',
      _ => sport.isEmpty ? sport : sport[0].toUpperCase() + sport.substring(1),
    };
  }

  static IconData _sportIcon(String sport) {
    return switch (sport) {
      'swimming' => ActivityType.swimming.icon,
      'cycling' => ActivityType.cycling.icon,
      'running' => ActivityType.running.icon,
      _ => ActivityType.other.icon,
    };
  }
}
