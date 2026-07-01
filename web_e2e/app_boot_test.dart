// WEB end-to-end smoke: boots the REAL app in a REAL browser and asserts it
// reaches the welcome screen without crashing. Unlike the widget smoke tests
// (which run in the Dart VM and stub the network), this exercises the actual
// web bootstrap — Supabase init, SharedPreferences, routing — so it catches
// web-only breakage that VM tests cannot, including the class of CORS/edge
// failures fixed in fix/web-edge-functions-cors.
//
// Run: scripts/run_web_e2e.sh  (starts chromedriver, passes the dev defines)
//
// This deliberately does NOT log in — a no-auth boot smoke is the robust first
// rung. To extend to authenticated flows, add a test that finds the email/
// password fields (give them Keys in email_login_screen.dart) and a button by
// text, then tap through with a dedicated dev test account. flutter drive can
// drive the widget tree directly (it is not blind to the canvas the way
// Playwright is).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web app boots to the welcome screen without crashing',
      (tester) async {
    final config = AppConfig.fromDartDefines();
    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
    );
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const RootAppWidget(),
      ),
    );

    // Poll for the welcome surface. We deliberately do NOT use pumpAndSettle:
    // the real app has continuous work (Sentry, Supabase, splash animations,
    // timers) that can keep the frame scheduler busy indefinitely, so
    // pumpAndSettle would time out even on a healthy boot. Instead, pump in
    // fixed steps and check each frame — this tolerates slow web startup and
    // never hangs.
    bool welcomeVisible() =>
        find.text('Get Started').evaluate().isNotEmpty ||
        find.text('Log In').evaluate().isNotEmpty;

    const deadline = Duration(seconds: 40);
    final sw = Stopwatch()..start();
    while (!welcomeVisible() && sw.elapsed < deadline) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // If the boot crashed (white screen / DB failure) the welcome CTAs never
    // appear and this fails — exactly what we want to catch (e.g. the migration
    // "duplicate column" boot crash, or the CORS storm stalling startup).
    expect(
      welcomeVisible(),
      isTrue,
      reason: 'Expected the welcome screen (Get Started / Log In) within '
          '${deadline.inSeconds}s of boot; the app likely crashed on startup.',
    );

    // No unhandled framework exceptions during boot.
    expect(tester.takeException(), isNull);
  });
}
