import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/app_startup/presentation/screens/force_upgrade_screen.dart';

/// Pins where "Update Now" sends the user.
///
/// This screen has `canPop: false`, so a wrong URL is not a cosmetic bug — it
/// strands the user on a dead end with no way forward. It has already happened
/// once: the screen shipped with a placeholder App Store id (`id123456789`) and
/// the wrong Android package, so the button was dead on both platforms.
///
/// The dev/prod split is the load-bearing part. The dev build is distributed
/// through TestFlight under a *different bundle id*
/// (`com.milkman.mealvanaendurance.dev`), so sending a dev tester to the public
/// App Store listing would offer them the prod app — which cannot update the
/// build they are stuck in.
void main() {
  String url({
    required bool isDevFlavor,
    bool isWeb = false,
    bool isIOS = false,
    bool isAndroid = false,
  }) =>
      ForceUpgradeScreen.storeUrlFor(
        isDevFlavor: isDevFlavor,
        isWeb: isWeb,
        isIOS: isIOS,
        isAndroid: isAndroid,
      );

  group('iOS', () {
    test('prod → the real App Store listing', () {
      // 6751113738 is the live "Mealvana Endurance" listing (Milkman Inc).
      expect(
        url(isDevFlavor: false, isIOS: true),
        'https://apps.apple.com/app/id6751113738',
      );
    });

    test('dev → TestFlight, NOT the App Store', () {
      final u = url(isDevFlavor: true, isIOS: true);
      expect(u, contains('testflight.apple.com'));
      expect(
        u,
        isNot(contains('apps.apple.com')),
        reason: 'the store listing is the prod bundle — it cannot update dev',
      );
    });
  });

  group('Android', () {
    test('prod → the real package', () {
      expect(
        url(isDevFlavor: false, isAndroid: true),
        'https://play.google.com/store/apps/details?id=com.milkman.mealvanaendurance',
      );
    });

    test('dev → the .dev package suffix', () {
      expect(
        url(isDevFlavor: true, isAndroid: true),
        'https://play.google.com/store/apps/details?id=com.milkman.mealvanaendurance.dev',
      );
    });

    // The original bug: the package was `com.mealvana.endurance`, which does not
    // exist. Both flavors must carry the real `com.milkman.` prefix.
    test('never the old bogus package name', () {
      for (final dev in [true, false]) {
        expect(
          url(isDevFlavor: dev, isAndroid: true),
          isNot(contains('com.mealvana.endurance')),
        );
        expect(url(isDevFlavor: dev, isAndroid: true),
            contains('com.milkman.mealvanaendurance'));
      }
    });
  });

  group('web and fallback', () {
    test('web → the web app', () {
      for (final dev in [true, false]) {
        expect(url(isDevFlavor: dev, isWeb: true), 'https://app.mealvana.io');
      }
    });

    test('unknown platform falls back to the web app rather than nothing', () {
      expect(url(isDevFlavor: false), 'https://app.mealvana.io');
    });
  });

  test('no URL is ever empty — an empty URL is a dead button', () {
    for (final dev in [true, false]) {
      for (final p in [
        (isWeb: true, isIOS: false, isAndroid: false),
        (isWeb: false, isIOS: true, isAndroid: false),
        (isWeb: false, isIOS: false, isAndroid: true),
        (isWeb: false, isIOS: false, isAndroid: false),
      ]) {
        final u = url(
          isDevFlavor: dev,
          isWeb: p.isWeb,
          isIOS: p.isIOS,
          isAndroid: p.isAndroid,
        );
        expect(u, isNotEmpty);
        expect(Uri.tryParse(u), isNotNull);
      }
    }
  });
}
