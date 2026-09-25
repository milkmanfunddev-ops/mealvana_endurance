/// The Code entry sheet on its own (testing-wave 81): the field fits the
/// longest Code there is (11-004) and a Code refused as too long is said so
/// in the app's words (11-003). The paywall's tests cover opening it and what
/// each answer does to the screen under it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/subscription/application/code_entry_controller.dart';
import 'package:mealvana_endurance/features/subscription/domain/code_redemption.dart';
import 'package:mealvana_endurance/features/subscription/presentation/widgets/redeem_code_sheet.dart';

import '../../meal_planning/presentation/helpers/test_content.dart';
import '../code_entry_fakes.dart';

final _content = loadDefaultContent();

Future<void> _pump(WidgetTester tester, RecordingCodeEntry entry) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentServiceProvider.overrideWith(
          (ref) => TestContentService(ref, _content),
        ),
        codeEntryControllerProvider.overrideWith(() => entry),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => RedeemCodeSheet(host: context)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the field stops at 32 characters, the longest Code there is '
      '(11-004)', (tester) async {
    final entry = RecordingCodeEntry(
      const CodeRefused(reason: CodeRefusal.notFound),
    );
    await _pump(tester, entry);

    await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), 'x' * 45);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(RedeemCodeSheet.fieldKey),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, 'X' * 32);
    expect(RedeemCodeSheet.maxCodeLength, 32);
  });

  testWidgets('a Code refused as too long is said so, in the app\'s words '
      '(11-003)', (tester) async {
    final entry = RecordingCodeEntry(
      const CodeRefused(reason: CodeRefusal.tooLong),
    );
    await _pump(tester, entry);

    await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), 'ABC');
    await tester.pump();
    await tester.tap(find.byKey(RedeemCodeSheet.submitKey));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(RedeemCodeSheet.problemKey)).data,
      _content['redeem_code.refused_too_long'],
    );
    expect(find.byType(RedeemCodeSheet), findsOneWidget);
  });

  testWidgets('a Code from a coach already asked to pair is said so, in the '
      'app\'s words (11-002, ticket 95)', (tester) async {
    final entry = RecordingCodeEntry(
      const CodeRefused(reason: CodeRefusal.alreadyPaired),
    );
    await _pump(tester, entry);

    await tester.enterText(find.byKey(RedeemCodeSheet.fieldKey), 'KYLE18');
    await tester.pump();
    await tester.tap(find.byKey(RedeemCodeSheet.submitKey));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(RedeemCodeSheet.problemKey)).data,
      "You've already asked this coach to pair.",
    );
    expect(
      _content['redeem_code.refused_already_paired'],
      "You've already asked this coach to pair.",
    );
    expect(find.byType(RedeemCodeSheet), findsOneWidget);
  });
}
