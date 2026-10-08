// Ticket 66 (testing-wave develop-2026-10, Finding 50-008): iOS names the app
// "Mealvana" in system prompts.
//
// The ASWebAuthenticationSession prompt reads `CFBundleName`, which was the
// literal "mealvana_endurance" ("“mealvana_endurance” Wants to Use
// “vdoto2.com” to Sign In"). Both flavours build from this one plist, so one
// value covers dev and prod. The home-screen label stays the flavour's
// `BUNDLE_DISPLAY_NAME`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `<string>` right after `<key>[key]</key>`.
String? _plistString(String plist, String key) => RegExp(
  '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
).firstMatch(plist)?.group(1);

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('CFBundleName is "Mealvana"', () {
    expect(_plistString(plist, 'CFBundleName'), 'Mealvana');
  });

  test('CFBundleDisplayName is still the flavour display name', () {
    expect(
      _plistString(plist, 'CFBundleDisplayName'),
      r'$(BUNDLE_DISPLAY_NAME)',
    );
  });
}
