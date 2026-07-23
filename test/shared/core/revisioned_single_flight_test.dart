import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/core/revisioned_single_flight.dart';

void main() {
  test('concurrent callers for one key share one operation', () async {
    final coordinator = RevisionedSingleFlight<int>();
    final completer = Completer<int>();
    var calls = 0;
    var joins = 0;

    Future<int> operation() {
      calls++;
      return completer.future;
    }

    final first = coordinator.run('week', operation: operation);
    final second = coordinator.run(
      'week',
      operation: operation,
      onJoin: () => joins++,
    );

    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(joins, 1);

    completer.complete(7);
    expect(await first, 7);
    expect(await second, 7);
  });

  test('a change during a pass schedules exactly one fresh pass', () async {
    final coordinator = RevisionedSingleFlight<int>();
    final firstPass = Completer<int>();
    var calls = 0;
    var clears = 0;
    var reruns = 0;

    Future<int> operation() {
      calls++;
      return calls == 1 ? firstPass.future : Future.value(2);
    }

    final result = coordinator.run(
      'week',
      operation: operation,
      beforeRerun: () async => clears++,
      onRerun: () => reruns++,
    );

    coordinator.markChanged('week');
    coordinator.markChanged('week');
    firstPass.complete(1);

    expect(await result, 2);
    expect(calls, 2, reason: 'multiple edits collapse into one follow-up pass');
    expect(clears, 1);
    expect(reruns, 1);
  });

  test(
    'a change before work starts does not force a redundant rerun',
    () async {
      final coordinator = RevisionedSingleFlight<int>();
      var calls = 0;
      coordinator.markChanged('week');

      final result = await coordinator.run(
        'week',
        operation: () async => ++calls,
      );

      expect(result, 1);
      expect(calls, 1);
    },
  );
}
