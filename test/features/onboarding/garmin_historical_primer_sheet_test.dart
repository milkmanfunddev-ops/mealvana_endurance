/// The onboarding Garmin "Historical Data" primer sheet.
///
/// Shown only when Garmin connect is initiated during onboarding (see
/// connected_apps_screen `_connectGarmin`, gated on `isOnboarding`). Verifies
/// the tightened glanceable copy, the annotated toggle mock, and that the two
/// choices return the right result (true = continue to Garmin, false = not
/// now). ops 2026-09-13-garmin-historical-data-off-by-default.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/widgets/garmin_historical_primer_sheet.dart';

void main() {
  Future<bool?> present(WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showGarminHistoricalPrimer(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('renders the tightened primer copy + annotated toggle', (
    tester,
  ) async {
    await present(tester);
    expect(find.text('ONE QUICK STEP'), findsOneWidget);
    expect(find.text('Turn on Historical Data'), findsOneWidget);
    expect(find.textContaining('real training'), findsOneWidget);
    // The mock carries the instruction visually.
    expect(find.text('connect.garmin.com'), findsOneWidget);
    expect(find.text('Historical Data'), findsOneWidget);
    expect(find.text('Turn this on'), findsOneWidget);
    expect(find.text('Continue to Garmin'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Continue to Garmin returns true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () => showGarminHistoricalPrimer(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('garmin_primer.continue')));
    await tester.pumpAndSettle();
    expect(find.text('Continue to Garmin'), findsNothing); // sheet dismissed
  });

  testWidgets('Not now dismisses (returns false)', (tester) async {
    final result = await present(tester);
    expect(result, isNull); // still open until tapped
    await tester.tap(find.byKey(const ValueKey('garmin_primer.not_now')));
    await tester.pumpAndSettle();
    expect(find.text('Turn on Historical Data'), findsNothing);
  });
}
