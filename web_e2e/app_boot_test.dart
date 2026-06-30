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

    // Let startup (DB init, auth restore, first route) settle. The real app on
    // web takes a beat; pumpAndSettle with a generous timeout, then assert the
    // unauthenticated landing surface is present.
    await tester.pumpAndSettle(const Duration(seconds: 20));

    // Welcome screen CTAs. If the boot crashed (white screen / exception) these
    // would be absent and the test fails — exactly what we want to catch.
    final getStarted = find.text('Get Started');
    final logIn = find.text('Log In');
    expect(
      getStarted.evaluate().isNotEmpty || logIn.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected the welcome screen (Get Started / Log In) after boot.',
    );

    // No unhandled framework exceptions during boot.
    expect(tester.takeException(), isNull);
  });
}
