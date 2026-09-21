/// A refresh cannot start a second day-note generation (ai-cost ticket 13,
/// mp-478).
///
/// Every `get_home` on a stale note is what asks the server to write the notes
/// again, so the count that matters is the number of `get_home` calls the real
/// [HomeController] makes. The payload is the `home.json` contract fixture —
/// producer-shaped, straight off the endpoint — with its plan dropped so the
/// load does not reach into [MealPlanController]; a payload with no plan is
/// exactly what the server sends an athlete who has none.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/meal_planning/application/home_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/home_payload.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';

/// The fixture payload with the day note's `stale` flag set as the test wants
/// and the plan taken out.
HomePayload homeFixture({required bool stale}) {
  final home = Map<String, dynamic>.from(
    loadFixture('home')['home'] as Map<String, dynamic>,
  )..remove('batch');
  final payload = HomePayload.fromJson(home);
  return payload.copyWith(vana: payload.vana.copyWith(stale: stale));
}

/// Counts `get_home` calls and, when gated, holds each one open until released.
class _CountingHomeService extends Fake implements HomeService {
  _CountingHomeService({required this.payload, this.gated = false});

  final HomePayload Function() payload;
  final bool gated;
  int fetches = 0;
  final List<Completer<HomePayload>> pending = [];

  @override
  Future<HomePayload> fetch({String? date}) {
    fetches++;
    if (!gated) return Future.value(payload());
    final c = Completer<HomePayload>();
    pending.add(c);
    return c.future;
  }

  void releaseAll() {
    for (final c in pending) {
      if (!c.isCompleted) c.complete(payload());
    }
    pending.clear();
  }
}

void main() {
  /// A container with the Plan tab's subscription in place. Without a listener
  /// Riverpod disposes the controller between reads and the next read builds a
  /// fresh one, which would fetch again for reasons that have nothing to do
  /// with what is under test.
  ProviderContainer containerWith(_CountingHomeService service) {
    final container = testContainer([
      ...baseOverrides(),
      homeServiceProvider.overrideWithValue(service),
    ]);
    container.listen(homeControllerProvider(), (_, _) {}, fireImmediately: true);
    return container;
  }

  test('a refresh that lands mid-load joins it instead of asking again', () async {
    final service = _CountingHomeService(
      payload: () => homeFixture(stale: true),
      gated: true,
    );
    final container = containerWith(service);

    final first = container.read(homeControllerProvider().future);
    await settle();
    expect(service.fetches, 1);

    // Three pull-to-refreshes while the server is still writing the notes.
    final refreshes = [
      for (var i = 0; i < 3; i++)
        container.read(homeControllerProvider().notifier).refresh(),
    ];
    await settle();
    expect(
      service.fetches,
      1,
      reason: 'a refresh joins the get_home in flight, it does not add one',
    );

    service.releaseAll();
    await first;
    await Future.wait(refreshes);
    expect(service.fetches, 1);
  });

  test('the stale-poll budget is spent once, not refilled by every refresh', () {
    fakeAsync((async) {
      final service = _CountingHomeService(
        payload: () => homeFixture(stale: true),
      );
      final container = containerWith(service);

      async.elapse(const Duration(milliseconds: 50));

      // Let every scheduled poll fire: one load plus maxStalePolls polls.
      async.elapse(HomeController.stalePollDelay * (HomeController.maxStalePolls + 2));
      final afterPolls = service.fetches;
      expect(afterPolls, 1 + HomeController.maxStalePolls);

      // Pulling to refresh re-reads the payload, and that is all — it buys no
      // further polls while the note is still stale.
      for (var i = 0; i < 3; i++) {
        container.read(homeControllerProvider().notifier).refresh();
        async.elapse(const Duration(milliseconds: 50));
      }
      async.elapse(HomeController.stalePollDelay * (HomeController.maxStalePolls + 2));
      expect(
        service.fetches,
        afterPolls + 3,
        reason: 'three refreshes, three get_home calls, no new poll chain',
      );
    });
  });

  test('fresh notes refill the budget, so the next edit is still polled for', () {
    fakeAsync((async) {
      var stale = true;
      final service = _CountingHomeService(payload: () => homeFixture(stale: stale));
      final container = containerWith(service);

      async.elapse(const Duration(milliseconds: 50));
      async.elapse(HomeController.stalePollDelay * (HomeController.maxStalePolls + 2));
      expect(service.fetches, 1 + HomeController.maxStalePolls);

      // The notes land. The next refresh sees them and the budget resets.
      stale = false;
      container.read(homeControllerProvider().notifier).refresh();
      async.elapse(const Duration(milliseconds: 50));
      final atFresh = service.fetches;
      async.elapse(HomeController.stalePollDelay * 2);
      expect(service.fetches, atFresh, reason: 'a fresh note is not polled for');

      // A new edit makes it stale again: the polls come back.
      stale = true;
      container.read(homeControllerProvider().notifier).refresh();
      async.elapse(const Duration(milliseconds: 50));
      async.elapse(HomeController.stalePollDelay * (HomeController.maxStalePolls + 2));
      expect(service.fetches, atFresh + 1 + HomeController.maxStalePolls);
    });
  });
}
