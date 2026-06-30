import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/fuel_timeline_filter.dart';
import '../fuel_timeline_type.dart';

/// The segmented `All · Workout · Meals` control plus the round Tracking and
/// Timeline toggle buttons. (The AI "Suggest" toggle is deferred.)
class FuelFilterRow extends StatelessWidget {
  const FuelFilterRow({
    super.key,
    required this.filter,
    required this.trackingOn,
    required this.timelineOpen,
    required this.onPickFilter,
    required this.onToggleTracking,
    required this.onToggleTimeline,
  });

  final FuelTimelineFilter filter;
  final bool trackingOn;
  final bool timelineOpen;
  final ValueChanged<FuelTimelineFilter> onPickFilter;
  final VoidCallback onToggleTracking;
  final VoidCallback onToggleTimeline;

  @override
  Widget build(BuildContext context) {
    const onSurface = AppColors.cream;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: onSurface.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                _segment(context, 'All', FuelTimelineFilter.all, onSurface),
                _segment(
                  context,
                  'Workout',
                  FuelTimelineFilter.workout,
                  onSurface,
                ),
                _segment(context, 'Meals', FuelTimelineFilter.meals, onSurface),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _toggle(
          context: context,
          keyValue: 'fuel_timeline.tracking_toggle',
          icon: Icons.show_chart, // pulse line, matching the mockup
          active: trackingOn,
          activeColor: AppColors.dragonfruit,
          onTap: onToggleTracking,
          tooltip: trackingOn ? 'Turn tracking off' : 'Turn tracking on',
        ),
        const SizedBox(width: 8),
        _toggle(
          context: context,
          keyValue: 'fuel_timeline.timeline_toggle',
          icon: timelineOpen ? Icons.schedule : Icons.history_toggle_off,
          active: timelineOpen,
          activeColor: AppColors.electrolyteDark,
          onTap: onToggleTimeline,
          tooltip: timelineOpen ? 'Hide times' : 'Show times',
        ),
      ],
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    FuelTimelineFilter value,
    Color onSurface,
  ) {
    final selected = filter == value;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('fuel_timeline.filter_${value.name}'),
        onTap: () => onPickFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: FtType.pill.copyWith(
              color: selected
                  ? AppColors.blackberry
                  : onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle({
    required BuildContext context,
    required String keyValue,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    const onSurface = AppColors.cream;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: ValueKey(keyValue),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? activeColor.withValues(alpha: 0.16)
                : onSurface.withValues(alpha: 0.05),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.6)
                  : onSurface.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? activeColor : onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
