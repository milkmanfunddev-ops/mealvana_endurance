// Entryway widget L2 rows (carb-loading@v1 handback G9/G16 + the desk's
// walked contracts):
//  * `repick-dialog-backdrop-abort` / `repick-notice-backdrop-abort` — a tap
//    outside either re-pick dialog returns NULL (CE-9): nothing chosen,
//    nothing written. Negative is structural: the caller only applies on a
//    non-null result (pinned in carb_loading_repick_test).
//  * Keep/Reset carries exactly two choices; the F4 notice exactly one.
//  * `chooser-feasibility` L2 — infeasible cards render DISABLED WITH THE
//    REASON, never hidden; taps on them are no-ops; a feasible selection
//    pops its day count (F5 re-check inside).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_entryway_engine.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/widgets/carb_repick_dialogs.dart';

RepickDecision keepResetDecision() => RepickDecision(
  dialogType: RepickDialogType.keepReset,
  listedEdits: [
    RepickListedEdit(
      date: DateTime(2026, 9, 26),
      targetDayNumber: 1,
      storedG: 620,
    ),
  ],
  droppedDates: const [],
  keepPlanG: const [620, 748],
  resetPlanG: const [612, 748],
);

RepickDecision noticeDecision() => RepickDecision(
  dialogType: RepickDialogType.notice,
  listedEdits: const [],
  droppedDates: [DateTime(2026, 9, 26)],
  keepPlanG: const [748],
  resetPlanG: const [748],
);

Future<bool?> Function() pumpDialogHost(
  WidgetTester tester,
  Future<bool?> Function(BuildContext) show,
) {
  late Future<bool?> Function() opener;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  opener = () {
    final ctx = tester.element(find.byType(Scaffold));
    return show(ctx);
  };
  return opener;
}

Future<void> pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: SizedBox.expand())),
  );
}

void main() {
  group('G16 — CE-9 backdrop abort', () {
    testWidgets('keep/reset: barrier tap returns null; buttons return choice',
        (tester) async {
      await pumpHost(tester);
      final open = pumpDialogHost(
        tester,
        (ctx) => showCarbRepickKeepResetDialog(
          ctx,
          decision: keepResetDecision(),
        ),
      );

      // Abort via backdrop.
      var result = open();
      await tester.pumpAndSettle();
      expect(find.text('Keep your edited targets?'), findsOneWidget);
      // F3 DATA rendered: target-relabel with the date and stored grams.
      expect(
        find.textContaining('Day 1 (Sat, Sep 26) — you set 620 g'),
        findsOneWidget,
      );
      // Exactly two choices, no third button.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();
      expect(await result, isNull, reason: 'CE-9: backdrop tap aborts');
      expect(find.text('Keep your edited targets?'), findsNothing);

      // Keep.
      result = open();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('carb_repick.keep')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);

      // Reset.
      result = open();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('carb_repick.reset')));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('notice: single button proceeds; barrier tap aborts',
        (tester) async {
      await pumpHost(tester);
      final open = pumpDialogHost(
        tester,
        (ctx) => showCarbRepickNoticeDialog(
          ctx,
          decision: noticeDecision(),
          targetProtocolName: '1-Day',
        ),
      );

      var result = open();
      await tester.pumpAndSettle();
      expect(find.text('Edited target won’t carry over'), findsOneWidget);
      expect(
        find.textContaining('falls outside the window'),
        findsOneWidget,
        reason: 'Q-CL10: the drop is disclosed, never silent',
      );
      // Exactly ONE button — no vacuous Keep/Reset pair (F4).
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await result, isNull, reason: 'CE-9 applies to the notice too');

      result = open();
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('carb_repick.notice_proceed')));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
      expect(find.text('Switch to 1-Day'), findsNothing);
    });
  });

  group('G9 — chooser feasibility (CE-8)', () {
    Future<void> pumpChooser(
      WidgetTester tester, {
      required DateTime raceDate,
      int? current,
      List<int?>? popped,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      final r = await Navigator.of(context).push<int>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CarbLoadingProtocolSelectionScreen.forRepick(
                                raceDate: raceDate,
                                currentProtocolDays: current,
                              ),
                        ),
                      );
                      popped?.add(r);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    DateTime raceIn(int days) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day).add(Duration(days: days));
    }

    testWidgets('1 day out: 3- and 2-Day disabled WITH reason, never hidden',
        (tester) async {
      await pumpChooser(tester, raceDate: raceIn(1));
      // All three cards render (never hidden).
      expect(find.text('3-Day Classic'), findsOneWidget);
      expect(find.text('2-Day Quick'), findsOneWidget);
      expect(find.text('1-Day'), findsOneWidget);
      expect(find.text('Needs 3 days before race day'), findsOneWidget);
      expect(find.text('Needs 2 days before race day'), findsOneWidget);
      expect(find.text('Needs 1 day before race day'), findsNothing);
    });

    testWidgets('tapping a disabled card is a no-op; a feasible one pops',
        (tester) async {
      final popped = <int?>[];
      await pumpChooser(tester, raceDate: raceIn(1), popped: popped);
      // Disabled 3-Day: tap the card body — nothing happens.
      await tester.tap(find.text('3-Day Classic'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('3-Day Classic'), findsOneWidget,
          reason: 'still on the chooser');
      expect(popped, isEmpty);
      // Feasible 1-Day pops its day count.
      await tester.ensureVisible(
        find.byKey(const ValueKey('carb_loading.select_1_day_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('carb_loading.select_1_day_button')),
      );
      await tester.pumpAndSettle();
      expect(popped, [1]);
    });

    testWidgets('3+ days out: everything choosable; current plan tagged',
        (tester) async {
      await pumpChooser(tester, raceDate: raceIn(5), current: 3);
      expect(find.textContaining('Needs '), findsNothing);
      expect(find.text('CURRENT PLAN'), findsOneWidget);
    });
  });
}
