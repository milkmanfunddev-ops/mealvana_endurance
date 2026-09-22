// An install left anonymous from before the paywall lands on the account
// screen (mp-455 §4, mp-417 §1; paywall ticket 09): every signed-in route
// sends an anonymous session there, before the subscription gate is asked.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/presentation/old_install_redirect.dart';

void main() {
  test(
    'an anonymous session on a signed-in route goes to the account screen',
    () {
      for (final path in ['/main', '/paywall', '/food', '/settings']) {
        expect(
          oldAnonymousInstallRedirect(path: path, anonymous: true),
          kOldInstallAccountLocation,
          reason: path,
        );
      }
      expect(kOldInstallAccountLocation, '/auth/post-onboarding?mode=signup');
    },
  );

  test('a signed-up account is left to the gate', () {
    expect(
      oldAnonymousInstallRedirect(path: '/main', anonymous: false),
      isNull,
    );
  });

  test('the account screen and the other open routes are never redirected', () {
    for (final path in [
      '/',
      '/welcome',
      '/onboarding',
      '/auth/post-onboarding',
      '/auth/email-signup',
      '/privacy-consent',
      '/force-upgrade',
    ]) {
      expect(
        oldAnonymousInstallRedirect(path: path, anonymous: true),
        isNull,
        reason: path,
      );
    }
  });
}
