import 'package:flutter/material.dart';

import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';

/// The filter pill row + tracking / time-rail toggles.
/// The pill drives the energy card's face (energy-card.md state model) and
/// the timeline filter.
class DashboardFilterRow extends StatelessWidget {
  const DashboardFilterRow({
    super.key,
    required this.filter,
    required this.trackingOn,
    required this.timelineOpen,
    required this.onFilter,
    required this.onToggleTracking,
    required this.onToggleTimeline,
  });

  final DashboardFilter filter;
  final bool trackingOn;
  final bool timelineOpen;
  final ValueChanged<DashboardFilter> onFilter;
  final VoidCallback onToggleTracking;
  final VoidCallback onToggleTimeline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: MeTokens.creamAlpha(0.1)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                _pill('All', DashboardFilter.all),
                const SizedBox(width: 5),
                _pill('Workout', DashboardFilter.workout),
                const SizedBox(width: 5),
                _pill('Meals', DashboardFilter.meals),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _roundButton(
          key: const ValueKey('macro_dashboard.tracking_toggle'),
          tooltip: trackingOn ? 'Turn tracking off' : 'Turn tracking on',
          icon: Icons.show_chart,
          background: trackingOn
              ? MeTokens.dragonfruit.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          border: trackingOn
              ? MeTokens.dragonfruit.withValues(alpha: 0.6)
              : MeTokens.creamAlpha(0.18),
          ink: trackingOn ? MeTokens.dragonfruit : MeTokens.creamAlpha(0.55),
          onTap: onToggleTracking,
        ),
        const SizedBox(width: 8),
        _roundButton(
          key: const ValueKey('macro_dashboard.timeline_toggle'),
          tooltip: timelineOpen ? 'Hide times' : 'Show times',
          icon: timelineOpen ? Icons.schedule : Icons.history_toggle_off,
          background: timelineOpen
              ? MeTokens.electrolyteAlpha(0.12)
              : Colors.white.withValues(alpha: 0.05),
          border: timelineOpen
              ? MeTokens.electrolyteAlpha(0.55)
              : MeTokens.creamAlpha(0.18),
          ink: timelineOpen ? MeTokens.electrolyte : MeTokens.creamAlpha(0.55),
          onTap: onToggleTimeline,
        ),
      ],
    );
  }

  Widget _pill(String label, DashboardFilter value) {
    final active = filter == value;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('macro_dashboard.filter_${value.name}'),
        onTap: () => onFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? MeTokens.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              color: active ? MeTokens.blackberry : MeTokens.creamAlpha(0.65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    Key? key,
    required String tooltip,
    required IconData icon,
    required Color background,
    required Color border,
    required Color ink,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 17, color: ink),
        ),
      ),
    );
  }
}
