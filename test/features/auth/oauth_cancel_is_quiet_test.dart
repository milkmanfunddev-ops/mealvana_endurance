/// Cancels stay quiet (testing-wave 125-003): closing Google's picker or
/// Apple's sheet is not a failure. The service throws a typed
/// [OAuthCancelledException]; the real [PostOnboardingAuthController] logs it
/// at info and never as an error, and hands it to the screen as a typed error
/// state, which the screen swallows. The simulator's Apple `unknown` is not a
/// cancel and stays a failure.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/oauth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../helpers/widget_test_harness.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

/// The native plugins cannot run headless: the service is pinned to a cancel
/// (or a failure) while the controller stays real.
class _CancellingOAuthService extends OAuthService {
  _CancellingOAuthService(this.error);

  final Object error;

  @override
  Future<void> build() async {}

  @override
  Future<void> signInWithGoogle() async => throw error;

  @override
  Future<void> signInWithApple() async => throw error;

  @override
  Future<void> linkGoogleAccount() async => throw error;

  @override
  Future<void> linkAppleAccount() async => throw error;
}

({ProviderContainer container, MockAppLogger logger}) _controller(
  Object error,
) {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final logger = MockAppLogger();
  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: _MockSupabase(),
          sentry: MockSentryReporter(),
          logger: logger,
          sharedPreferences: MockSharedPreferences(),
        ),
      ),
      analyticsTrackerProvider.overrideWithValue(analytics),
      oAuthServiceProvider.overrideWith(() => _CancellingOAuthService(error)),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, logger: logger);
}

void _neverLoggedAnError(MockAppLogger logger) => verifyNever(
  () => logger.error(
    any(),
    context: any(named: 'context'),
    error: any(named: 'error'),
    data: any(named: 'data'),
    stackTrace: any(named: 'stackTrace'),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group('OAuthService.isCancellation (seam: the plugins\' errors)', () {
    test('Apple: ASAuthorizationError.canceled (1001) is a cancel', () {
      expect(
        OAuthService.isCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'The user canceled the authorization attempt.',
          ),
        ),
        isTrue,
      );
    });

    test('Apple: the simulator\'s unknown stays a failure', () {
      expect(
        OAuthService.isCancellation(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.unknown,
            message: 'The operation couldn\'t be completed. (error 1000.)',
          ),
        ),
        isFalse,
      );
    });

    test('Google: the plugin\'s cancel codes are cancels', () {
      expect(
        OAuthService.isCancellation(
          PlatformException(code: 'sign_in_canceled', message: 'cancelled'),
        ),
        isTrue,
      );
      expect(
        OAuthService.isCancellation(Exception('Status 12501: cancelled')),
        isTrue,
      );
      expect(
        OAuthService.isCancellation(
          const OAuthCancelledException(provider: 'google'),
        ),
        isTrue,
      );
    });

    test('a network failure is not a cancel', () {
      expect(
        OAuthService.isCancellation(
          PlatformException(code: 'network_error', message: 'offline'),
        ),
        isFalse,
      );
    });
  });

  group('PostOnboardingAuthController (real controller)', () {
    for (final provider in ['google', 'apple']) {
      test('a $provider cancel reaches the screen as a cancel, '
          'with no error log', () async {
        final wired = _controller(OAuthCancelledException(provider: provider));
        final controller = wired.container.read(
          postOnboardingAuthControllerProvider.notifier,
        );

        final success = provider == 'google'
            ? await controller.signInWithGoogle()
            : await controller.signInWithApple();

        expect(success, isFalse);
        final state = wired.container.read(postOnboardingAuthControllerProvider);
        expect(state.error, isA<OAuthCancelledException>());
        expect((state.error as OAuthCancelledException).provider, provider);
        _neverLoggedAnError(wired.logger);
      });

      test('a $provider link cancel (old install) is quiet too', () async {
        final wired = _controller(OAuthCancelledException(provider: provider));
        final controller = wired.container.read(
          postOnboardingAuthControllerProvider.notifier,
        );

        final success = provider == 'google'
            ? await controller.linkGoogleAccount()
            : await controller.linkAppleAccount();

        expect(success, isFalse);
        expect(
          wired.container.read(postOnboardingAuthControllerProvider).error,
          isA<OAuthCancelledException>(),
        );
        _neverLoggedAnError(wired.logger);
      });
    }

    test('a real failure is still logged as an error', () async {
      final wired = _controller(Exception('no ID token received'));
      final controller = wired.container.read(
        postOnboardingAuthControllerProvider.notifier,
      );

      expect(await controller.signInWithGoogle(), isFalse);
      verify(
        () => wired.logger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          data: any(named: 'data'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
