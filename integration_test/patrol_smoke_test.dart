/// Patrol smoke test — proves the native test target is wired up correctly.
///
/// This test does almost nothing on purpose: it launches the dev app, waits
/// for the first frame, and asserts that *some* widget rendered. The point is
/// to validate the toolchain (`patrol test` → xcodebuild test → XCUITest →
/// patrol package binding → Flutter app) before adding any flow logic.
///
/// Run with:
///   patrol test --target integration_test/patrol_smoke_test.dart \
///     --flavor dev -t lib/main_dev.dart \
///     -d "iPhone 15 Pro Max"
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;

void main() {
  patrolTest(
    'app launches and renders at least one widget',
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    ($) async {
      await app.main();
      await $.pumpAndSettle(timeout: const Duration(seconds: 30));

      expect(find.byType(Widget), findsWidgets);
    },
  );
}
