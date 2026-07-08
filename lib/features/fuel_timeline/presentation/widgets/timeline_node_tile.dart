import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/timeline_node.dart';
import '../fuel_timeline_type.dart';

/// One row on the Fuel Timeline: the optional left time-rail + the node card.
///
/// Phase 2 renders cards display-only (meal macro line + workout summary).
/// Tap interactions — expand/Swap/Remove on meals, open the Ride Fuel sheet on
/// workouts — arrive in Phase 3 via [onTap].
class TimelineNodeTile extends ConsumerWidget {
  const TimelineNodeTile({
    super.key,
    required this.node,
    required this.timelineOpen,
    required this.trackingOn,
    this.onTap,
    this.onSwap,
    this.onRemove,
  });

  final TimelineNode node;
  final bool timelineOpen;
  final bool trackingOn;

  /// Tap on the card: opens the edit-meal page, or the activity detail page.
  final VoidCallback? onTap;

  /// Meal-only swipe actions: swipe left→right removes, right→left swaps
  /// (mirrors the Activity Detail food rows).
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
        // Untagged meals (slot is optional — build-a-meal redesign) get a
        // neutral dot rather than crashing the exhaustive switch.
        null => AppColors.electrolyte,
      },
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;
    // Foreground reads cream-on-blackberry in dark mode, blackberry-on-cream
    // in light mode (matches the app's Kyle light/dark token pair).
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    // The rail dot's border is meant to visually match the screen behind it
    // (a "cutout" ring), so it must track the real background, not a fixed
    // dark value.
    final surfaceBg = isDark ? AppColors.blackberry : AppColors.cream;
    final dotColor = _dotColor(node);

    // stretch so the rail's full-height line fills each row and consecutive
    // rows' lines abut into one continuous rail. The cards are pinned to the
    // top via Align so they keep their natural height while the rail runs the
    // full row height (including the 16px inter-row gap below each card).
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
                    _timeFmt.format(node.time),
                    textAlign: TextAlign.right,
                    style: FtType.macroLine.copyWith(
                      color: onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _rail(onSurface, dotColor, surfaceBg),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: switch (node) {
                  MealNode(:final meal) => _mealCard(context, meal, onSurface),
                  WorkoutNode(:final activity) => _workoutCard(
                    context,
                    activity,
                    onSurface,
                    useMetric,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rail(Color onSurface, Color dotColor, Color surfaceBg) {
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
                border: Border.all(color: surfaceBg, width: 2),
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
    final card = _cardShell(
      onSurface: onSurface,
      borderColor: onSurface.withValues(alpha: 0.08),
      fill: onSurface.withValues(alpha: 0.045),
      padded: false,
      child: GestureDetector(
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
            ],
          ),
        ),
      ),
    );

    // No swipe actions wired up → return the bare card.
    if (onSwap == null && onRemove == null) return card;

    // Swipe right→left (endToStart) = Remove, swipe left→right (startToEnd) =
    // Swap — the iOS-conventional "swipe left to delete". Matches the Activity
    // Detail food rows (DismissibleFoodItem). confirmDismiss always returns
    // false: the actions run via callbacks (Remove soft-deletes with Undo; Swap
    // navigates) and never structurally dismiss the row.
    return Dismissible(
      key: ValueKey('timeline-meal-${node.id}'),
      background: _swipeBackground(
        color: AppColors.electrolyteDark,
        icon: Icons.swap_horiz,
        label: 'Swap',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onRemove?.call();
        } else if (direction == DismissDirection.startToEnd) {
          onSwap?.call();
        }
        return false;
      },
      child: card,
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeft
            ? [
                Icon(icon, color: AppColors.cream, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: FtType.itemName.copyWith(color: AppColors.cream)),
              ]
            : [
                Text(label,
                    style: FtType.itemName.copyWith(color: AppColors.cream)),
                const SizedBox(width: 8),
                Icon(icon, color: AppColors.cream, size: 20),
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

  Widget _workoutCard(
    BuildContext context,
    dynamic activity,
    Color onSurface,
    bool useMetric,
  ) {
    final subtitle = _workoutSubtitle(activity, useMetric);
    final card = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.45)),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            _iconCircle(
              AppColors.electrolyteDark,
              // Real activity-type icon (was hardcoded to the cycling icon
              // for every workout).
              activity.activityType.icon as IconData,
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
                    'Pre · During · Recovery fuel',
                    style: FtType.macroLine.copyWith(color: AppColors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // No swipe actions wired up (e.g. import-only activities have no edit
    // affordance) → return the bare card.
    if (onSwap == null && onRemove == null) return card;

    // Swipe right→left (endToStart) = Remove, swipe left→right (startToEnd) =
    // Edit — the iOS-conventional "swipe left to delete". Mirrors the meal
    // row's Dismissible above: confirmDismiss always returns false, the
    // actions run via callbacks (Remove deletes with Undo; Edit navigates)
    // and never structurally dismiss the row.
    return Dismissible(
      key: ValueKey('timeline-workout-${node.id}'),
      background: _swipeBackground(
        color: AppColors.electrolyteDark,
        icon: Icons.edit_outlined,
        label: 'Edit',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onRemove?.call();
        } else if (direction == DismissDirection.startToEnd) {
          onSwap?.call();
        }
        return false;
      },
      child: card,
    );
  }

  String? _workoutSubtitle(dynamic activity, bool useMetric) {
    final parts = <String>[];
    final dist = activity.distanceMiles as double?;
    final speed = activity.cyclingSpeedMph as double?;
    final dur = activity.durationMinutes as int?;
    if (dist != null) {
      parts.add(
        UnitFormatter.formatDistance(
          dist,
          unit: useMetric ? DistanceUnit.kilometers : DistanceUnit.miles,
        ),
      );
    }
    if (speed != null) {
      parts.add(UnitFormatter.formatSpeed(speed, useMetric: useMetric));
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
