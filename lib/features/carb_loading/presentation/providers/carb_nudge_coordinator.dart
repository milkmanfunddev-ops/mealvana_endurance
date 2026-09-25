import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/services/logging_service.dart';
import '../../../events/domain/event.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../application/carb_load_nudge_service.dart';
import '../../application/carb_loading_service.dart';

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
    try {
      final events = await ref.read(allEventsProvider.future);
      final carbService = ref.read(carbLoadingServiceProvider);
      final nudgeService = ref.read(carbLoadNudgeServiceProvider);

      final nudgeEvents = <CarbNudgeEvent>[];
      final withPlan = <String>{};
      for (final Event event in events) {
        final raceDate = event.eventDate ??
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
      ref
          .read(appLoggerProvider)
          .warning(
            'Carb nudge sweep failed; will retry on next resume',
            context: 'CARB_NUDGE',
            error: e,
            stackTrace: stackTrace,
          );
    } finally {
      _running = false;
    }
  }
}
