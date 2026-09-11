/// The Situation the client reports: one entry per screen in the spec's table,
/// through the real notifier, plus the staleness rule and the wire shape.
///
/// The route strings here must match the server's screen table in
/// `supabase/functions/_shared/vana/situation.ts`; its own tests assert the same
/// strings from the other side.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_situation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_situation_scope.dart';

void main() {
  final saturday = DateTime(2026, 9, 12);

  group('VanaSituationController', () {
    test('starts with nothing to say', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(vanaSituationControllerProvider), isNull);
      expect(
        c.read(vanaSituationControllerProvider.notifier).current(),
        isNull,
      );
    });

    test(
      'emits the right route, entity and date for every screen in the table',
      () {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(vanaSituationControllerProvider.notifier);

        final cases = <VanaSituation, Map<String, dynamic>>{
          VanaSituation.screen(
            VanaScreen.planTab,
            entityId: 'plan-1',
            date: saturday,
          ): {
            'route': '/food',
            'entityId': 'plan-1',
            'date': '2026-09-12',
          },
          VanaSituation.screen(VanaScreen.mealDetail, entityId: 'D-048'): {
            'route': '/food/meals/:id',
            'entityId': 'D-048',
          },
          VanaSituation.screen(VanaScreen.cookingMode, entityId: 'D-048'): {
            'route': '/food/cook/:id',
            'entityId': 'D-048',
          },
          VanaSituation.screen(
            VanaScreen.fuelLog,
            entityId: 'act-1',
            date: saturday,
          ): {
            'route': '/fuel-log',
            'entityId': 'act-1',
            'date': '2026-09-12',
          },
          VanaSituation.screen(VanaScreen.activityPlan, entityId: 'act-1'): {
            'route': '/plan',
            'entityId': 'act-1',
          },
          VanaSituation.screen(VanaScreen.currentPlan, entityId: 'act-1'): {
            'route': '/current-plan',
            'entityId': 'act-1',
          },
          VanaSituation.screen(VanaScreen.eventChecklist, entityId: 'ev-1'): {
            'route': '/events/:eventId/checklist',
            'entityId': 'ev-1',
          },
          VanaSituation.screen(VanaScreen.events): {'route': '/events'},
          VanaSituation.screen(
            VanaScreen.mealLog,
            date: saturday,
            slot: 'dinner',
          ): {
            'route': '/meal-log',
            'date': '2026-09-12',
            'slot': 'dinner',
          },
          VanaSituation.screen(VanaScreen.main, date: saturday): {
            'route': '/main',
            'date': '2026-09-12',
          },
        };

        for (final entry in cases.entries) {
          n.report(entry.key);
          expect(
            c.read(vanaSituationControllerProvider)!.toJson(),
            entry.value,
          );
          expect(n.current()!.toJson(), entry.value);
        }
      },
    );

    test('any other screen reports its route and nothing else', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.report(const VanaSituation.route('/settings/allergies'));
      expect(n.current()!.toJson(), {'route': '/settings/allergies'});
    });

    test('a report older than the ttl stops speaking for the athlete', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));

      final justInside = DateTime.now().add(
        vanaSituationTtl - const Duration(seconds: 1),
      );
      final wellPast = DateTime.now().add(
        vanaSituationTtl + const Duration(minutes: 1),
      );
      expect(n.current(now: justInside), isNotNull);
      expect(n.current(now: wellPast), isNull);
    });

    test(
      'leaving a screen does not clear it — opening Vana means leaving it',
      () {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(vanaSituationControllerProvider.notifier);
        n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));
        // No screen reports on the Vana routes; the fuel log is still the answer.
        expect(n.current()!.route, '/fuel-log');
        n.clear();
        expect(n.current(), isNull);
      },
    );

    test('the newest screen wins', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));
      n.report(VanaSituation.screen(VanaScreen.mealDetail, entityId: 'D-048'));
      expect(n.current()!.route, '/food/meals/:id');
    });

    test('a screen with no scope speaks as its route, not as the last '
        'scoped screen', () {
      // The sheet opens over settings after the athlete left the fuel log:
      // the fuel log is not what they are looking at any more.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.routeOnTop('/fuel-log');
      n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));
      n.routeOnTop('/settings');
      expect(n.current()!.toJson(), {'route': '/settings'});
    });

    test('a scoped screen that came on top speaks for itself', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.routeOnTop('/settings');
      n.routeOnTop('/fuel-log');
      n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));
      expect(n.current()!.toJson(), {'route': '/fuel-log', 'entityId': 'act-1'});
    });

    test('coming back to a screen hands back what it reported', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.routeOnTop('/main');
      n.report(VanaSituation.screen(VanaScreen.main, date: saturday));
      n.routeOnTop('/fuel-log');
      n.report(VanaSituation.screen(VanaScreen.fuelLog, entityId: 'act-1'));
      n.routeOnTop('/main');
      expect(n.current()!.toJson(), {'route': '/main', 'date': '2026-09-12'});
    });

    test('the route-only fallback never goes stale', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.routeOnTop('/settings');
      final later = DateTime.now().add(const Duration(hours: 3));
      expect(n.current(now: later)!.route, '/settings');
    });

    test('clear forgets the route too', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(vanaSituationControllerProvider.notifier);
      n.routeOnTop('/settings');
      n.clear();
      expect(n.current(), isNull);
    });
  });

  group('VanaSituationScope', () {
    testWidgets('a screen reports what it has in view, once it is on screen', (
      tester,
    ) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: VanaSituationScope(
              situation: VanaSituation.screen(
                VanaScreen.fuelLog,
                entityId: 'act-1',
                date: saturday,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(c.read(vanaSituationControllerProvider)!.toJson(), {
        'route': '/fuel-log',
        'entityId': 'act-1',
        'date': '2026-09-12',
      });
    });

    testWidgets('a screen still loading reports nothing', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(
            home: VanaSituationScope(situation: null, child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider), isNull);
    });

    testWidgets('an offscreen tab does not speak for the athlete', (
      tester,
    ) async {
      // An IndexedStack builds every child. Without the visibility marker the
      // last tab to build wins, and the athlete on tab 0 is reported as being
      // on tab 2.
      final c = ProviderContainer();
      addTearDown(c.dispose);

      Widget tab(int i, VanaSituation s, int current) =>
          VanaSituationVisibility(
            visible: i == current,
            child: VanaSituationScope(
              situation: s,
              child: const SizedBox.shrink(),
            ),
          );

      Future<void> pumpAt(int current) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: IndexedStack(
              index: current,
              children: [
                tab(
                  0,
                  VanaSituation.screen(VanaScreen.main, date: saturday),
                  current,
                ),
                tab(
                  1,
                  VanaSituation.screen(VanaScreen.planTab, entityId: 'plan-1'),
                  current,
                ),
                tab(2, VanaSituation.screen(VanaScreen.events), current),
              ],
            ),
          ),
        ),
      );

      await pumpAt(0);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.route, '/main');

      // Switching tabs hands over to the newly visible one.
      await pumpAt(1);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.route, '/food');

      await pumpAt(2);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.route, '/events');
    });

    testWidgets('a screen that changes what it shows reports again', (
      tester,
    ) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      Future<void> pumpWith(String id) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: VanaSituationScope(
              situation: VanaSituation.screen(
                VanaScreen.mealDetail,
                entityId: id,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await pumpWith('D-048');
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.entityId, 'D-048');

      await pumpWith('D-012');
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.entityId, 'D-012');
    });

    testWidgets('the tab shell speaks for a tab with no scope of its own', (
      tester,
    ) async {
      // Food reports for itself; Learn has no scope. Going Food → Learn must
      // not leave the Food Situation standing — every tab shares `/main`.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      const tabs = ['timeline', 'food', 'learn'];

      Future<void> pumpAt(int current) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: VanaSituationScope(
              situation: VanaSituation.shellTab(tabs[current], saturday),
              child: IndexedStack(
                index: current,
                children: [
                  for (final (i, _) in tabs.indexed)
                    VanaSituationVisibility(
                      visible: i == current,
                      child: i == 1
                          ? VanaSituationScope(
                              situation: VanaSituation.screen(
                                VanaScreen.planTab,
                                entityId: 'plan-1',
                              ),
                              child: const SizedBox.shrink(),
                            )
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      await pumpAt(0);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.toJson(), {
        'route': '/main',
        'date': '2026-09-12',
      });

      await pumpAt(1);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.toJson(), {
        'route': '/food',
        'entityId': 'plan-1',
      });

      await pumpAt(2);
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.toJson(), {
        'route': '/learn',
      });
    });

    testWidgets('a screen reports again when it comes back on top', (
      tester,
    ) async {
      // Meal A, then meal B pushed over it, then back to A: the same route
      // pattern both times, so only A reporting again can say it is A.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final navigator = GlobalKey<NavigatorState>();

      Widget meal(String id) => VanaSituationScope(
        situation: VanaSituation.screen(VanaScreen.mealDetail, entityId: id),
        child: const SizedBox.shrink(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(navigatorKey: navigator, home: meal('D-048')),
        ),
      );
      await tester.pump();
      expect(c.read(vanaSituationControllerProvider)!.entityId, 'D-048');

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => meal('D-012')),
      );
      await tester.pumpAndSettle();
      expect(c.read(vanaSituationControllerProvider)!.entityId, 'D-012');

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(c.read(vanaSituationControllerProvider)!.entityId, 'D-048');
    });
  });
}
