import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/vana_part.dart';
import 'meal_plan_controller.dart';

part 'youre_set_controller.g.dart';

/// The "you're set" card owed on Food > Shopping (mp-235): the plan just
/// confirmed, and the week laid across it once the athlete asks.
class YoureSet {
  const YoureSet({required this.planId, this.week});

  /// The plan the confirm returned. The card shows only over this plan's
  /// list.
  final String planId;

  /// "Lay it across the week": the read-only day cards, null until asked.
  final VanaWeekPart? week;
}

/// Which plan is owed the "you're set" card (mp-235, ticket 131).
///
/// [MealPlanController.confirmPlan] sets it on every confirm the server
/// acknowledged (the Review sheet, the Plan tab, an earlier plan), and each
/// of those lands on Food > Shopping, where the card sits at the top of the
/// new list. It shows once: dismissing it or leaving Shopping clears it,
/// so the next open has none. In memory only, so a relaunch has none either.
///
/// Session-scoped (`keepAlive`): the confirm happens on one screen and the
/// card draws on another.
@Riverpod(keepAlive: true)
class YoureSetController extends _$YoureSetController {
  /// "Lay it across the week" on the wire. A second tap joins it.
  Future<VanaWeekPart?>? _layingAcross;

  @override
  FutureOr<YoureSet?> build() {
    // Riverpod reuses this notifier across `invalidate`: start clean.
    _layingAcross = null;
    return null;
  }

  /// A confirm landed: [planId] is owed the card. A later confirm replaces
  /// an earlier one's card, week and all.
  void confirmed(String planId) {
    state = AsyncData(YoureSet(planId: planId));
  }

  /// The athlete closed the card or left Shopping: it does not come back.
  void dismiss() {
    if (state.value == null) return;
    state = const AsyncData(null);
  }

  /// "Lay it across the week" (mp-235 detail 3): `plan_week` lays the
  /// confirmed collection over the period's days and the card shows them
  /// read-only. Remote-ack: offline or refused it rethrows and the card
  /// stays as it was, so the screen can say why. A tap while one is on the
  /// wire joins it. An answer that lands after the card was dismissed, or
  /// after another confirm replaced it, is dropped.
  Future<VanaWeekPart?> layAcrossWeek() {
    final inFlight = _layingAcross;
    if (inFlight != null) return inFlight;
    final planId = state.value?.planId;
    if (planId == null) return Future.value();
    late final Future<VanaWeekPart?> call;
    call = _layAcross(planId).whenComplete(() {
      // A block body: returning the cleared Future would make whenComplete
      // wait on itself.
      if (identical(_layingAcross, call)) _layingAcross = null;
    });
    _layingAcross = call;
    return call;
  }

  Future<VanaWeekPart?> _layAcross(String planId) async {
    final week = await ref.read(mealPlanControllerProvider.notifier).planWeek();
    if (ref.mounted && week != null && state.value?.planId == planId) {
      state = AsyncData(YoureSet(planId: planId, week: week));
    }
    return week;
  }
}
