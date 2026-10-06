// Ticket 17 (Sentry MEALVANA-ENDURANCE-A6 / BY): Sign in with Apple on Android
// threw "`webAuthenticationOptions` argument must be provided on Android".
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/apple_web_authentication.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

void main() {
  group('appleWebAuthenticationOptions', () {
    test('iOS gets no options (native sheet, bundle ID)', () {
      expect(
        appleWebAuthenticationOptions(
          isAndroid: false,
          servicesId: 'com.milkman.mealvanaendurance.auth',
          supabaseUrl: 'https://wvmvsodrvbkxfydabqed.supabase.co',
        ),
        isNull,
      );
    });

    test('Android prod: Services ID + the prod relay return URL', () {
      final options = appleWebAuthenticationOptions(
        isAndroid: true,
        servicesId: 'com.milkman.mealvanaendurance.auth',
        supabaseUrl: 'https://wvmvsodrvbkxfydabqed.supabase.co',
      )!;
      expect(options.clientId, 'com.milkman.mealvanaendurance.auth');
      expect(
        options.redirectUri.toString(),
        'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/apple-signin-callback',
      );
    });

    test('Android dev: return URL follows the dev project, trailing slash tolerated', () {
      final options = appleWebAuthenticationOptions(
        isAndroid: true,
        servicesId: ' com.example.dev.auth ',
        supabaseUrl: 'https://vlmtsdzpnjnavdgytcmi.supabase.co/',
      )!;
      expect(options.clientId, 'com.example.dev.auth');
      expect(
        options.redirectUri.toString(),
        'https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/apple-signin-callback',
      );
    });

    test('never points Apple at Supabase /auth/v1/callback (cannot return to the app)', () {
      final options = appleWebAuthenticationOptions(
        isAndroid: true,
        servicesId: 'com.milkman.mealvanaendurance.auth',
        supabaseUrl: 'https://wvmvsodrvbkxfydabqed.supabase.co',
      )!;
      expect(options.redirectUri.path, isNot('/auth/v1/callback'));
    });

    test('Android without a Services ID throws a named error, not the plugin crash', () {
      expect(
        () => appleWebAuthenticationOptions(
          isAndroid: true,
          servicesId: '',
          supabaseUrl: 'https://vlmtsdzpnjnavdgytcmi.supabase.co',
        ),
        throwsA(isA<AppleSignInNotConfiguredException>()),
      );
    });
  });

  group('appleSignInAvailableProvider', () {
    ProviderContainer containerWith(String servicesId) {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.forTesting(appleAuthServicesId: servicesId),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android without a Services ID hides the Apple button', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(containerWith('').read(appleSignInAvailableProvider), isFalse);
    });

    test('Android with a Services ID shows it', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        containerWith('com.milkman.mealvanaendurance.auth')
            .read(appleSignInAvailableProvider),
        isTrue,
      );
    });

    test('iOS shows it regardless', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(containerWith('').read(appleSignInAvailableProvider), isTrue);
    });
  });
}
