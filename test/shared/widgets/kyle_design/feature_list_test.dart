/// feature-list spec (PROPOSED v1, paywall ticket 14 — mp-493 §2):
///   FL-1  headline rows carry a body; the divider and the title-only rows
///         come after, and the divider only when there are more rows
///   FL-2  each row leads with its mark (a glass icon disc or Vana)
///   FL-4  each row reads as one sentence to a screen reader
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/feature_list.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/icons/vana_avatar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';

FeatureListItem _item(String title, {String? body, bool vana = false}) =>
    FeatureListItem(
      leading: vana
          ? const VanaAvatar(size: 40)
          : const FeatureListIcon(Icons.bolt),
      title: title,
      body: body,
    );

Future<void> _pump(WidgetTester tester, FeatureList list) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: list)),
  ),
);

void main() {
  testWidgets('FL-1 headline rows, then the divider, then the rest', (
    tester,
  ) async {
    await _pump(
      tester,
      FeatureList(
        headline: [
          _item('Fuel', body: 'Every session'),
          _item('Vana', body: 'Plans, answers, logs', vana: true),
        ],
        dividerLabel: 'Also includes',
        more: [
          _item('Recipes', body: 'never shown'),
          _item('Sync'),
        ],
      ),
    );

    expect(find.text('Every session'), findsOneWidget);
    expect(find.text('Plans, answers, logs'), findsOneWidget);
    // More rows are title-only.
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('never shown'), findsNothing);
    expect(find.text('ALSO INCLUDES'), findsOneWidget);

    double top(Finder f) => tester.getTopLeft(f).dy;
    expect(
      top(find.byKey(FeatureList.headlineKey(1))),
      lessThan(top(find.byKey(FeatureList.dividerKey))),
    );
    expect(
      top(find.byKey(FeatureList.dividerKey)),
      lessThan(top(find.byKey(FeatureList.moreKey(0)))),
    );
  });

  testWidgets('FL-1 no more rows, no divider', (tester) async {
    await _pump(
      tester,
      FeatureList(
        headline: [_item('Fuel', body: 'Every session')],
        dividerLabel: 'Also includes',
      ),
    );
    expect(find.byKey(FeatureList.dividerKey), findsNothing);
  });

  testWidgets('FL-2 marks: a glass disc, or Vana', (tester) async {
    await _pump(
      tester,
      FeatureList(
        headline: [
          _item('Fuel', body: 'Every session'),
          _item('Vana', body: 'Plans', vana: true),
        ],
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(FeatureList.headlineKey(0)),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(FeatureList.headlineKey(1)),
        matching: find.byType(VanaAvatar),
      ),
      findsOneWidget,
    );
  });

  testWidgets('FL-4 a row is one sentence to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      FeatureList(headline: [_item('Fuel', body: 'Every session')]),
    );
    expect(
      tester.getSemantics(find.byKey(FeatureList.headlineKey(0))),
      matchesSemantics(label: 'Fuel\nEvery session'),
    );
    handle.dispose();
  });
}
