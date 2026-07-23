/// Patrol smoke test — proves the native test target is wired up correctly.
///
/// This test does almost nothing on purpose: it launches the dev app, waits
/// for the first frame, and asserts that *some* widget rendered. The point is
/// to validate the toolchain (`patrol test` → xcodebuild test → XCUITest →
/// patrol package binding → Flutter app) before adding any flow logic.
///
/// Run with:
///   patrol test --target integration_test/patrol_smoke_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     -d "iPhone 17 Pro"
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'helpers/flow_launcher.dart';

void main() {
  patrolTest(
    'app launches and renders at least one widget',
    ($) async {
      // Flavor-aware boot via the shared launcher (helpers/flow_launcher.dart).
      await launchApp();
      await $.pump(const Duration(seconds: 5));

      // Assert *some* widget rendered. NOTE: `find.byType(Widget)` is wrong —
      // byType matches the EXACT runtime type, and `Widget` is abstract, so it
      // always finds 0. Match every widget via a predicate instead.
      expect(find.byWidgetPredicate((_) => true), findsWidgets);
    },
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    // Fail fast: without this, a lost native-automation handshake (seen on the
    // iOS 26.2 simulator) leaves the run hanging until the ~2h xcodebuild test
    // timeout. Cap the Dart side aggressively.
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
