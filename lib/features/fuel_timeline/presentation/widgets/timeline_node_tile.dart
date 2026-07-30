import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../domain/timeline_node.dart';
import '../fuel_timeline_type.dart';

/// One row on the Fuel Timeline: the optional left time-rail + the node card.
///
/// Phase 2 renders cards display-only (meal macro line + workout summary).
/// Tap interactions — expand/Swap/Remove on meals, open the Ride Fuel sheet on
/// workouts — arrive in Phase 3 via [onTap].
class TimelineNodeTile extends StatelessWidget {
  const TimelineNodeTile({
    super.key,
    required this.node,
    required this.timelineOpen,
    required this.trackingOn,
    this.expanded = false,
    this.onTap,
    this.onSwap,
    this.onRemove,
  });

  final TimelineNode node;
  final bool timelineOpen;
  final bool trackingOn;

  /// Whether this meal's inline Swap/Remove actions are showing.
  final bool expanded;

  /// Tap on the card: toggles meal expand, or opens the Ride Fuel sheet.
  final VoidCallback? onTap;

  /// Meal-only inline actions.
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;

  static final _timeFmt = DateFormat('h:mm a');

  /// Timeline dot colour by what the node tracks (per the mockup): workouts
  /// orange, and meals tinted by their slot.
  static Color _dotColor(TimelineNode node) {
    return switch (node) {
      // Workouts get the electrolyte teal of their icon so they read
      // distinctly from meal dots on the rail.
      WorkoutNode() => AppColors.electrolyteDark,
      MealNode(:final meal) => switch (meal.slot) {
        MealSlot.breakfast => AppColors.orange,
        MealSlot.lunch => kMacroColorCarbs,
        MealSlot.snack => AppColors.dragonfruit,
        MealSlot.dinner => kMacroColorProtein,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    const onSurface = AppColors.cream;
    final dotColor = _dotColor(node);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (timelineOpen) ...[
            SizedBox(
              width: 54,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  _timeFmt.format(node.time),
                  textAlign: TextAlign.right,
                  style: FtType.macroLine.copyWith(
                    color: onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _rail(onSurface, dotColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: switch (node) {
                MealNode(:final meal) => _mealCard(context, meal, onSurface),
                WorkoutNode(:final activity) => _workoutCard(
                  context,
                  activity,
                  onSurface,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail(Color onSurface, Color dotColor) {
    return SizedBox(
      width: 16,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Full-height connecting line (top:0 → bottom:0 so consecutive rows
          // join into one continuous rail, per the mockup).
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
                color: dotColor,
                border: Border.all(color: AppColors.blackberry, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealCard(BuildContext context, dynamic meal, Color onSurface) {
    // meal is MealLog (typed via the switch pattern in build()).
    final macroLine = _macroLine(meal, onSurface);
    return _cardShell(
      onSurface: onSurface,
      borderColor: onSurface.withValues(alpha: 0.08),
      fill: onSurface.withValues(alpha: 0.045),
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  _iconCircle(
                    AppColors.orange,
                    Icons.restaurant,
                    AppColors.blackberry,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (meal.name as String).toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: FtType.itemName.copyWith(color: onSurface),
                        ),
                        if (trackingOn && macroLine != null) ...[
                          const SizedBox(height: 2),
                          macroLine,
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) _mealActions(onSurface),
        ],
      ),
    );
  }

  Widget _mealActions(Color onSurface) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(55, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              // Only one node is expanded at a time, so these keys stay unique.
              key: const ValueKey('timeline_node.swap_button'),
              onPressed: onSwap,
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface,
                side: BorderSide(color: onSurface.withValues(alpha: 0.12)),
                backgroundColor: onSurface.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(vertical: 7),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Swap food'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('timeline_node.remove_button'),
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dragonfruit,
                side: const BorderSide(color: AppColors.dragonfruit),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(vertical: 7),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _macroLine(dynamic meal, Color onSurface) {
    final cal = meal.calories as int?;
    final c = meal.carbsG as double?;
    final p = meal.proteinG as double?;
    final f = meal.fatG as double?;
    if (cal == null && c == null && p == null && f == null) return null;
    String g(double? v) => (v ?? 0).round().toString();
    final base = FtType.macroLine; // bold numbers
    // Separators/units stay light so the numbers pop (per the mockup).
    final sep = base.copyWith(
      fontWeight: FontWeight.w400,
      color: onSurface.withValues(alpha: 0.45),
    );
    // One ellipsizing line so a long row never overflows a narrow card.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${cal ?? 0}',
            style: base.copyWith(color: onSurface.withValues(alpha: 0.85)),
          ),
          TextSpan(text: ' kcal', style: sep),
          TextSpan(text: ' · ', style: sep),
          TextSpan(
            text: '${g(c)}C',
            style: base.copyWith(color: kMacroColorCarbs),
          ),
          TextSpan(text: ' · ', style: sep),
          TextSpan(
            text: '${g(p)}P',
            style: base.copyWith(color: kMacroColorProtein),
          ),
          TextSpan(text: ' · ', style: sep),
          TextSpan(
            text: '${g(f)}F',
            style: base.copyWith(color: kMacroColorFat),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _workoutCard(BuildContext context, dynamic activity, Color onSurface) {
    final subtitle = _workoutSubtitle(activity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            _iconCircle(
              AppColors.electrolyteDark,
              Icons.directions_bike,
              AppColors.blackberry,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (activity.title as String).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FtType.workoutName.copyWith(color: onSurface),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: FtType.macroLine.copyWith(
                        color: onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    'Pre · During · Recovery fuel ›',
                    style: FtType.macroLine.copyWith(color: AppColors.orange),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  String? _workoutSubtitle(dynamic activity) {
    final parts = <String>[];
    final dist = activity.distanceMiles as double?;
    final speed = activity.cyclingSpeedMph as double?;
    final dur = activity.durationMinutes as int?;
    if (dist != null) parts.add('${dist.toStringAsFixed(1)} mi');
    if (speed != null) {
      parts.add('${speed.toStringAsFixed(1)} mph');
    } else if (dur != null) {
      parts.add('$dur min');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _cardShell({
    required Color onSurface,
    required Color borderColor,
    required Color fill,
    required Widget child,
    bool padded = true,
  }) {
    return Container(
      padding: padded
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _iconCircle(Color bg, IconData icon, Color fg, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, size: size * 0.46, color: fg),
    );
  }
}
