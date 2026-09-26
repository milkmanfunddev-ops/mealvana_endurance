// Carb Slot Card L2 (components/carb-slot-card.md, RATIFIED 2026-09-25):
// SC-1 whole-surface door · SC-2 peek isolation (never navigates) · SC-3
// destination equality · SC-4 suppression (no steppers/remove in peek) ·
// the EMPTY/FILLED/PEEK states and the receipt rows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart'
    show CarbSlotCard;

void main() {
  Widget host({
    required bool isEmpty,
    bool peekOpen = false,
    VoidCallback? onOpen,
    VoidCallback? onTogglePeek,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF381633),
        body: Center(
          child: SizedBox(
            width: 360,
            child: CarbSlotCard(
              label: 'Breakfast',
              clockStr: '6:00 AM',
              headerFigure: isEmpty ? '0 / 136 g' : '124 / 136 g',
              isEmpty: isEmpty,
              summaryLine:
                  isEmpty ? '' : 'Everything Bagel with Cream Cheese +2 more',
              receiptRows: isEmpty
                  ? const []
                  : const [
                      ('Everything Bagel with Cream Cheese', '58 g'),
                      ('Granola Bar', '39 g'),
                      ('Chocolate Milk', '27 g'),
                    ],
              peekOpen: peekOpen,
              onOpen: onOpen ?? () {},
              onTogglePeek: onTogglePeek ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('EMPTY: header only — no summary, no chevron', (tester) async {
    await tester.pumpWidget(host(isEmpty: true));
    expect(
      find.textContaining('BREAKFAST', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('0 / 136 g'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('FILLED: header figure + ONE summary line', (tester) async {
    await tester.pumpWidget(host(isEmpty: false));
    expect(find.text('124 / 136 g'), findsOneWidget);
    expect(
      find.text('Everything Bagel with Cream Cheese +2 more'),
      findsOneWidget,
    );
    expect(find.text('58 g'), findsNothing, reason: 'receipt only in PEEK');
  });

  testWidgets('PEEK: read-only receipt + the SC-3 exit; SC-4 suppression',
      (tester) async {
    await tester.pumpWidget(host(isEmpty: false, peekOpen: true));
    expect(find.text('58 g'), findsOneWidget);
    expect(find.text('39 g'), findsOneWidget);
    expect(find.text('27 g'), findsOneWidget);
    expect(find.text('Edit in Breakfast ›'), findsOneWidget);
    // SC-4: no steppers, no remove affordances anywhere in the peek.
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('SC-1: the WHOLE surface is the door', (tester) async {
    var opened = 0;
    await tester.pumpWidget(host(isEmpty: false, onOpen: () => opened++));
    // Tap the summary line — not a button, still the door.
    await tester.tap(
      find.text('Everything Bagel with Cream Cheese +2 more'),
    );
    expect(opened, 1);
    // Tap the header figure too.
    await tester.tap(find.text('124 / 136 g'));
    expect(opened, 2);
  });

  testWidgets('SC-2: the chevron toggles peek ONLY — never opens the page',
      (tester) async {
    var opened = 0;
    var toggled = 0;
    await tester.pumpWidget(
      host(
        isEmpty: false,
        onOpen: () => opened++,
        onTogglePeek: () => toggled++,
      ),
    );
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    expect(toggled, 1);
    expect(opened, 0, reason: 'SC-2: chevron never navigates');
  });
}
