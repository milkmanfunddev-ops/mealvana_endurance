import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../events/domain/event.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../application/carb_load_nudge_service.dart';
import '../../application/carb_loading_service.dart';
import '../../../../shared/services/report/report.dart';

part 'carb_nudge_coordinator.g.dart';

/// G27: the open/resume sweep that keeps every event's scheduled nudges in
/// step with plan-existence and shows the at-most-one-per-day catch-up.
/// Called from the root widget on first frame and on every foreground
/// resume; every failure is swallowed — a nudge must never take the app
/// down (same fail-soft posture as the dashboard's carb watch).
@Riverpod(keepAlive: true)
class CarbNudgeCoordinator extends _$CarbNudgeCoordinator {
  bool _running = false;

  @override
  void build() {}

  Future<void> run() async {
    if (_running) return;
    _running = true;
    // Read before the first await: the container can be torn down while the
    // events load (Sentry MEALVANA-ENDURANCE-DEV-A3, a Patrol teardown).
    final report = ref.read(reportProvider);
    final carbService = ref.read(carbLoadingServiceProvider);
    final nudgeService = ref.read(carbLoadNudgeServiceProvider);
    try {
      final events = await ref.read(allEventsProvider.future);

      final nudgeEvents = <CarbNudgeEvent>[];
      final withPlan = <String>{};
      for (final Event event in events) {
        final raceDate =
            event.eventDate ??
            (event.startTime != null
                ? DateTime.tryParse(event.startTime!)
                : null);
        if (raceDate == null) continue;
        nudgeEvents.add((
          id: event.id,
          name: event.eventName ?? 'your race',
          raceDate: raceDate,
        ));
        if (await carbService.getCarbLoadingPlan(event.id) != null) {
          withPlan.add(event.id);
        }
      }

      await nudgeService.evaluateOnOpen(
        events: nudgeEvents,
        eventIdsWithPlan: withPlan,
      );
    } catch (e, stackTrace) {
      report.fault(
        e,
        stackTrace: stackTrace,
        area: 'carb_loading',
        message: 'Carb nudge sweep failed; will retry on next resume',
      );
    } finally {
      _running = false;
    }
  }
}
