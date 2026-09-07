import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/choice_chip_button.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/choice_chips.dart';

/// 02 §3 — a `choices` part always renders the compact chip [Wrap], one
/// pill per option; tapping a pill sends the label. Trade-off `details`
/// (spec §2.3) are deliberately NOT rendered — the labels carry the
/// meaning on their own (2026-09-04 walkthrough).
void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(
            File(
              'test/features/meal_planning/fixtures/$name.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  Future<void> pump(
    WidgetTester tester,
    VanaChoicesPart part,
    ValueChanged<String> onTap, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: ChoiceChips(part: part, onTap: onTap),
          ),
        ),
      ),
    );
  }

  testWidgets('without details: the chip Wrap, unchanged', (tester) async {
    final part = VanaChoicesPart.fromJson(fixture('choices'));
    final tapped = <String>[];
    await pump(tester, part, tapped.add);

    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(ChoiceChipButton), findsNWidgets(part.options.length));
    await tester.tap(find.text(part.options.first));
    expect(tapped, [part.options.first]);
  });

  testWidgets('with details: still compact pills, details never render', (
    tester,
  ) async {
    final part = VanaChoicesPart.fromJson(fixture('choices_details'));
    final tapped = <String>[];
    await pump(tester, part, tapped.add);

    expect(find.text(part.question!), findsOneWidget);
    expect(find.byType(Wrap), findsOneWidget);
    expect(find.byType(ChoiceChipButton), findsNWidgets(part.options.length));
    for (final option in part.options) {
      expect(find.text(option), findsOneWidget);
    }
    for (final detail in part.details) {
      if (detail != null) expect(find.text(detail), findsNothing);
    }

    await tester.tap(find.text('Batch cook'));
    expect(tapped, ['Batch cook']);
    await tester.tap(find.text('Cook most nights'));
    expect(tapped, ['Batch cook', 'Cook most nights']);
  });

  testWidgets('a null detail renders the same as any other option', (
    tester,
  ) async {
    const part = VanaChoicesPart(
      options: ['A', 'B'],
      details: ['only A explains itself', null],
    );
    await pump(tester, part, (_) {}, brightness: Brightness.dark);
    expect(find.byType(ChoiceChipButton), findsNWidgets(2));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('only A explains itself'), findsNothing);
  });
}
