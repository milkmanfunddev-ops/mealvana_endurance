// Regression coverage for bug 3a3e3fdb: the quick-log confirm sheet used to
// seed `eatenAt` from DateTime.now(), so quick-logging onto a back-dated day
// stamped the entry with today's date and it sank to the bottom of that day's
// fuel timeline instead of landing in its chronological slot.
//
// This sheet is the highest-traffic path — three LogMealScreen call sites
// (food/ingredient, recipe, saved meal) funnel through it — and it is the only
// one whose decision is returned as a directly assertable result object.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/presentation/widgets/quick_log_confirm_sheet.dart';

void main() {
  testWidgets('returns an eatenAt on the passed logDate, not today', (
    tester,
  ) async {
    QuickLogConfirmResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showQuickLogConfirmSheet(
                  context,
                  title: 'Test food',
                  logDate: '2026-07-19',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Test food'), findsOneWidget);

    await tester.tap(find.text('Log it'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.eatenAt.year, 2026);
    expect(result!.eatenAt.month, 7);
    expect(result!.eatenAt.day, 19);
  });

  testWidgets('seeds today when logDate is today', (tester) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    QuickLogConfirmResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showQuickLogConfirmSheet(
                  context,
                  title: 'Test food',
                  logDate: todayStr,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log it'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.eatenAt.year, today.year);
    expect(result!.eatenAt.month, today.month);
    expect(result!.eatenAt.day, today.day);
  });
}
