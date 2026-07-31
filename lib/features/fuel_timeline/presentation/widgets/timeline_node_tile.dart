import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/swipe_action_background.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../domain/timeline_node.dart';
import '../fuel_timeline_type.dart';

/// Shared by [TimelineNodeTile._cardShell] and its swipe reveals, so the
/// coloured background behind a swiped card is always the same shape as the
/// card itself.
const BorderRadius _kCardRadius = BorderRadius.all(Radius.circular(14));

/// One row on the Fuel Timeline: the optional left time-rail + the node card.
///
/// Unified card interaction (391e3fdb): tapping the card opens its detail/edit
/// surface via [onTap] (Swap lives inside those surfaces), and swiping the
/// card in EITHER direction fires [onRemove] — the same gesture contract as
/// every other meal/activity card in the app.
class TimelineNodeTile extends ConsumerWidget {
  const TimelineNodeTile({
    super.key,
    required this.node,
    required this.timelineOpen,
    required this.trackingOn,
    this.onTap,
    this.onRemove,
    this.selectionMode = false,
    this.selectable = false,
    this.selected = false,
    this.legOrder,
    this.onSelectToggle,
  });

  final TimelineNode node;
  final bool timelineOpen;
  final bool trackingOn;

  /// Brick leg-picking is active (step 2 of the brick flow). While true the
  /// row's normal tap/swipe contract is suspended: tapping a [selectable] row
  /// toggles it into the brick instead of opening its detail surface.
  final bool selectionMode;

  /// This row may be picked as a brick leg. Rows that are not brick-eligible
  /// (meals, races, strength work) stay visible but inert and dimmed.
  final bool selectable;

  /// This row is currently picked as a leg — draws the orange spine on the
  /// rail, "a live preview of the brick" (Notion 3a7e3fdb, step 2).
  final bool selected;

  /// 1-based leg position, shown in place of the rail dot while picked.
  final int? legOrder;

  /// Toggle this row in/out of the brick selection.
  final VoidCallback? onSelectToggle;

  /// Tap on the card: opens the edit-meal page, or the activity detail page.
  final VoidCallback? onTap;

  /// Swipe-to-delete in both directions. Null → the card is not deletable and
  /// renders without a Dismissible.
  final VoidCallback? onRemove;

  static final _timeFmt = DateFormat('h:mm a');

  /// Timeline dot colour by what the node tracks (per the mockup): workouts
  /// orange, and meals tinted by their slot.
  static Color _dotColor(TimelineNode node) {
    return switch (node) {
      // Workouts get the electrolyte teal of their icon so they read
      // distinctly from meal dots on the rail.
      WorkoutNode() => AppColors.electrolyteDark,
      // The race itself — dragonfruit, matching the event dot on the calendar.
      EventNode() => AppColors.dragonfruit,
      // Carb-loading days read as a carb (amber) dot.
      CarbLoadingNode() => kMacroColorCarbs,
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
                child: _maybeSelectable(switch (node) {
                  MealNode(:final meal) => _mealCard(context, meal, onSurface),
                  WorkoutNode(:final activity) => _workoutCard(
                    context,
                    activity,
                    onSurface,
                    useMetric,
                    surfaceBg,
                  ),
                  EventNode(:final event) => _eventCard(
                    context,
                    event,
                    onSurface,
                  ),
                  CarbLoadingNode(:final day, :final totalDays) => _carbCard(
                    context,
                    day,
                    totalDays,
                    onSurface,
                  ),
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// While leg-picking is active the card itself becomes the hit target:
  /// eligible rows toggle, ineligible rows dim and swallow the tap so a
  /// mis-tap can't navigate away mid-flow.
  Widget _maybeSelectable(Widget card) {
    if (!selectionMode) return card;
    if (!selectable) {
      return Opacity(opacity: 0.35, child: IgnorePointer(child: card));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelectToggle,
      // Absorb the card's own onTap/Dismissible so picking a leg can never
      // open a detail page or delete the row.
      child: IgnorePointer(child: card),
    );
  }

  Widget _rail(Color onSurface, Color dotColor, Color surfaceBg) {
    // Picked legs get an orange spine on the rail — "a live preview of the
    // brick" (Notion 3a7e3fdb, step 2). The spine replaces the hairline for
    // this row only, so the rail stays continuous and simply thickens where
    // the brick will be.
    final spine = selectionMode && selected;
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
              width: spine ? 4 : 2,
              decoration: BoxDecoration(
                color: spine
                    ? AppColors.orange
                    : onSurface.withValues(alpha: 0.22),
                borderRadius: spine ? BorderRadius.circular(2) : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: spine
                ? _legBadge(surfaceBg)
                : Container(
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

  /// The in-card pick marker: a hollow circle when the row can be picked, the
  /// filled orange leg number once it has been.
  Widget _pickMarker(Color surfaceBg, Color onSurface) {
    if (!selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onSurface.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.orange,
      ),
      child: Text(
        '${legOrder ?? ''}',
        style: FtType.macroLine.copyWith(
          fontSize: 11,
          height: 1.0,
          color: AppColors.blackberry,
        ),
      ),
    );
  }

  /// The ordered leg marker (1 / 2 / 3) that stands in for the rail dot while
  /// a row is picked.
  Widget _legBadge(Color surfaceBg) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.orange,
        border: Border.all(color: surfaceBg, width: 2),
      ),
      child: Text(
        '${legOrder ?? ''}',
        style: FtType.macroLine.copyWith(
          fontSize: 9,
          height: 1.0,
          color: AppColors.blackberry,
        ),
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

    // Nothing deletable wired up → return the bare card.
    if (onRemove == null) return card;

    // Swipe in EITHER direction = Remove (unified card interaction 391e3fdb).
    // Swap stays reachable via tap → edit-meal, which has per-component swap.
    // confirmDismiss always returns false: the delete runs via the callback
    // (soft-delete with Undo) and the row leaves through the provider rebuild,
    // never a structural dismiss.
    return Dismissible(
      key: ValueKey('timeline-meal-${node.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        onRemove?.call();
        return false;
      },
      child: card,
    );
  }

  /// Radius matches [_cardShell] exactly so the reveal is card-shaped.
  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    return SwipeActionBackground(
      alignment: alignment,
      color: color.withValues(alpha: 0.9),
      borderRadius: _kCardRadius,
      icon: Icon(icon, color: AppColors.cream, size: 20),
      label: label,
      labelStyle: FtType.itemName.copyWith(color: AppColors.cream),
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
    Color surfaceBg,
  ) {
    final subtitle = _workoutSubtitle(activity, useMetric);
    // While picking legs the card carries the choice itself: an empty circle
    // when it can be picked, the orange leg number once it is. The card also
    // drops its "Pre · During · Recovery fuel" line so the row reads as a
    // choice rather than a workout summary.
    final picking = selectionMode && selectable;
    final card = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.orange.withValues(alpha: 0.14)
            : AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppColors.orange
              : AppColors.orange.withValues(alpha: 0.45),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            if (picking) ...[
              _pickMarker(surfaceBg, onSurface),
              const SizedBox(width: 10),
            ],
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
                  if (!picking) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Pre · During · Recovery fuel',
                      style: FtType.macroLine.copyWith(color: AppColors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Nothing deletable wired up → return the bare card.
    if (onRemove == null) return card;

    // Swipe in EITHER direction = Remove (unified card interaction 391e3fdb).
    // Editing stays reachable via tap → the Activity Detail / editor surface.
    // Mirrors the meal row's Dismissible above: confirmDismiss always returns
    // false, the delete runs via the callback (with Undo) and the row leaves
    // through the provider rebuild, never a structural dismiss.
    return Dismissible(
      key: ValueKey('timeline-workout-${node.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: AppColors.dragonfruit,
        icon: Icons.delete_outline,
        label: 'Remove',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        onRemove?.call();
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

  /// The race/event banner on its day. Tapping opens the event detail.
  Widget _eventCard(BuildContext context, dynamic event, Color onSurface) {
    // event is Event (typed via the switch pattern in build()).
    final title = (event.eventName as String?)?.trim();
    final name = (title != null && title.isNotEmpty) ? title : 'Race day';
    final subtitle = event.eventSubtype as String?;

    return _cardShell(
      onSurface: onSurface,
      borderColor: AppColors.dragonfruit.withValues(alpha: 0.35),
      fill: AppColors.dragonfruit.withValues(alpha: 0.08),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            _iconCircle(
              AppColors.dragonfruit.withValues(alpha: 0.18),
              Icons.emoji_events_outlined,
              AppColors.dragonfruit,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: FtType.itemName.copyWith(color: onSurface)),
                  Text(
                    subtitle != null && subtitle.isNotEmpty
                        ? 'Event · $subtitle'
                        : 'Event',
                    style: FtType.macroLine.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A carb-loading day banner. Tapping opens the carb loading day.
  Widget _carbCard(
    BuildContext context,
    dynamic day,
    int? totalDays,
    Color onSurface,
  ) {
    // day is CarbLoadingDay (typed via the switch pattern in build()).
    final dayNumber = day.dayNumber as int;
    final target = day.carbTargetGrams as int;
    final label = totalDays != null
        ? 'Carb Loading · Day $dayNumber of $totalDays'
        : 'Carb Loading · Day $dayNumber';

    return _cardShell(
      onSurface: onSurface,
      borderColor: kMacroColorCarbs.withValues(alpha: 0.35),
      fill: kMacroColorCarbs.withValues(alpha: 0.08),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            _iconCircle(
              kMacroColorCarbs.withValues(alpha: 0.18),
              Icons.bolt_outlined,
              kMacroColorCarbs,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: FtType.itemName.copyWith(color: onSurface),
                  ),
                  Text(
                    'Target ${target}g carbs',
                    style: FtType.macroLine.copyWith(
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        borderRadius: _kCardRadius,
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
