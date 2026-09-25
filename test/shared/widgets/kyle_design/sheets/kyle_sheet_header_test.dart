/// Testing-wave 08-002: the sheet header's X had no accessibility label, so
/// VoiceOver read it as "button" on every sheet that uses the header.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/sheets/kyle_sheet_header.dart';

void main() {
  testWidgets('the close button is a button named Close', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KyleSheetHeader(title: 'Redeem a code', onClose: () {}),
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('kyle_sheet_header.close')),
      ),
      isSemantics(label: 'Close', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
