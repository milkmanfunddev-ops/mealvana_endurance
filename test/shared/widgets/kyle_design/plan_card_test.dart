/// plan-card spec (PROPOSED v1, paywall ticket 15 — mp-493 §3, §6):
///   PC-1  one plan: title, the billed price, and what the caller adds
///         (struck-through normal price, per-month line, trial note, badge)
///   PC-2  selected vs not: one tap selects; the card never buys
///   PC-3  the billed price outranks the per-month line
///   PC-4  a card reads as one selectable item to a screen reader
///   PC-5  the tray pins the cards above one action, on glass
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/plan_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('PC-1 title, price and every optional line the caller gives', (
    tester,
  ) async {
    await _pump(
      tester,
      PlanCard(
        title: 'Annual',
        price: r'$99.99 / year',
        regularPrice: r'$199.99 / year',
        detail: r'$8.33 a month',
        note: '7 days free',
        badge: 'Save 33%',
        selected: true,
        onSelected: () {},
      ),
    );

    expect(find.text('Annual'), findsOneWidget);
    expect(find.text(r'$99.99 / year'), findsOneWidget);
    expect(find.text(r'$8.33 a month'), findsOneWidget);
    expect(find.text('7 days free'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    final regular = tester.widget<Text>(find.byKey(PlanCard.regularPriceKey));
    expect(regular.data, r'$199.99 / year');
    expect(regular.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('PC-1 the optional lines are absent unless given', (
    tester,
  ) async {
    await _pump(
      tester,
      PlanCard(
        title: 'Monthly',
        price: r'$24.99 / month',
        selected: false,
        onSelected: () {},
      ),
    );
    for (final key in [
      PlanCard.regularPriceKey,
      PlanCard.detailKey,
      PlanCard.noteKey,
      PlanCard.badgeKey,
    ]) {
      expect(find.byKey(key), findsNothing, reason: '$key');
    }
  });

  testWidgets('PC-2 a tap selects; selected and unselected differ', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlanCard(
            key: const ValueKey('a'),
            title: 'Annual',
            price: 'A',
            selected: true,
            onSelected: () {},
          ),
          PlanCard(
            key: const ValueKey('m'),
            title: 'Monthly',
            price: 'M',
            selected: false,
            onSelected: () => taps++,
          ),
        ],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('m')));
    expect(taps, 1);

    BoxDecoration frame(String key) =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byKey(PlanCard.frameKey),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(frame('a').border, isNot(frame('m').border));
  });

  testWidgets('PC-3 the billed price is larger than the per-month line', (
    tester,
  ) async {
    await _pump(
      tester,
      PlanCard(
        title: 'Annual',
        price: r'$199.99 / year',
        detail: r'$16.67 a month',
        selected: true,
        onSelected: () {},
      ),
    );
    double size(Key key) =>
        tester.widget<Text>(find.byKey(key)).style!.fontSize!;
    expect(size(PlanCard.priceKey), greaterThan(size(PlanCard.detailKey)));
  });

  testWidgets('PC-4 one selectable item to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      PlanCard(
        key: const ValueKey('card'),
        title: 'Annual',
        price: r'$199.99 / year',
        badge: 'Save 33%',
        selected: true,
        onSelected: () {},
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('card'))),
      isSemantics(
        label: 'Annual\nSave 33%\n\$199.99 / year',
        isButton: true,
        hasTapAction: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('PC-5 the tray: header, cards, then the action, on glass', (
    tester,
  ) async {
    await _pump(
      tester,
      PlanCardTray(
        header: const Text('Founding member', key: ValueKey('header')),
        cards: [
          PlanCard(
            key: const ValueKey('a'),
            title: 'Annual',
            price: 'A',
            selected: true,
            onSelected: () {},
          ),
          PlanCard(
            key: const ValueKey('m'),
            title: 'Monthly',
            price: 'M',
            selected: false,
            onSelected: () {},
          ),
        ],
        action: const Text('Continue', key: ValueKey('action')),
      ),
    );

    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    expect(top('header'), lessThan(top('a')));
    expect(top('a'), lessThan(top('m')));
    expect(top('m'), lessThan(top('action')));
    expect(
      find.descendant(
        of: find.byType(PlanCardTray),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
  });
}
