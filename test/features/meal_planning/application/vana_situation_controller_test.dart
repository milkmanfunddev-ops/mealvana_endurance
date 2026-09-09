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
  });
}
