/// Cancels stay quiet (testing-wave 125-003): closing Google's picker or
/// Apple's sheet is not a failure. The service throws a typed
/// [OAuthCancelledException]; the real [PostOnboardingAuthController] logs it
/// at info and never as an error, and hands it to the screen as a typed error
/// state, which the screen swallows. The simulator's Apple `unknown` is not a
/// cancel and stays a failure.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/oauth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';

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

({ProviderContainer container, RecordingReport report}) _controller(
  Object error,
) {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final report = RecordingReport();
  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: _MockSupabase(),
          sharedPreferences: MockSharedPreferences(),
          report: report,
        ),
      ),
      reportProvider.overrideWithValue(report),
      analyticsTrackerProvider.overrideWithValue(analytics),
      oAuthServiceProvider.overrideWith(() => _CancellingOAuthService(error)),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, report: report);
}

void _neverLoggedAnError(RecordingReport report) =>
    expect(report.faults, isEmpty);

/// A [RecordingReport] with `SentryReport`'s identity rule on its shared
/// registry (`report.dart`, `_capture`): the count of [faults] is the count
/// of Sentry events.
class _DedupingReport extends RecordingReport {
  bool _firstTime(Object error) {
    if (SentryReport.wasReported(error)) return false;
    SentryReport.markReported(error);
    return true;
  }

  @override
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    if (!_firstTime(error)) return;
    await super.fault(
      error,
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
    );
  }

  @override
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    if (!_firstTime(error)) return;
    await super.degraded(
      error,
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
    );
  }
}

const _googleChannel = MethodChannel('plugins.flutter.io/google_sign_in');
const _appleChannel = MethodChannel(
  'com.aboutyou.dart_packages.sign_in_with_apple',
);

/// The real [OAuthService] and controller, the real Riverpod net, and the
/// plugins answered over their own channels (develop-2026-10 ticket 41).
({
  ProviderContainer container,
  _DedupingReport report,
  RecordingAnalyticsTracker analytics,
})
_realService() {
  final goTrue = fakeGoTrueClient() as MockGoTrueClient;
  final prefs = MockSharedPreferences();
  when(() => prefs.getString(any())).thenReturn(null);
  final analytics = RecordingAnalyticsTracker();
  final report = _DedupingReport();
  final observer = SentryProviderObserver(report: report);
  final container = ProviderContainer(
    observers: [observer],
    retry: observer.retry,
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(auth: goTrue),
          sharedPreferences: prefs,
          report: report,
        ),
      ),
      reportProvider.overrideWithValue(report),
      analyticsTrackerProvider.overrideWithValue(analytics),
      sharedPreferencesProvider.overrideWithValue(prefs),
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(postOnboardingAuthControllerProvider, (_, _) {});
  return (container: container, report: report, analytics: analytics);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        final state = wired.container.read(
          postOnboardingAuthControllerProvider,
        );
        expect(state.error, isA<OAuthCancelledException>());
        expect((state.error as OAuthCancelledException).provider, provider);
        _neverLoggedAnError(wired.report);
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
        _neverLoggedAnError(wired.report);
      });
    }

    test('a real failure is still logged as an error', () async {
      // (the pinned service above; the real one is in the group below)
      final wired = _controller(Exception('no ID token received'));
      final controller = wired.container.read(
        postOnboardingAuthControllerProvider.notifier,
      );

      expect(await controller.signInWithGoogle(), isFalse);
      expect(wired.report.faults, hasLength(1));
    });
  });

  // develop-2026-10 ticket 41 (30-005): the real service reports before it
  // writes state, so the Riverpod net never captures the plugin's raw error
  // with no area.
  group('real OAuthService through the Riverpod net', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() {
      messenger.setMockMethodCallHandler(_googleChannel, null);
      messenger.setMockMethodCallHandler(_appleChannel, null);
    });

    test('Google\'s picker answering null is a cancel: no fault, no '
        'degraded, one count', () async {
      messenger.setMockMethodCallHandler(_googleChannel, (call) async => null);
      final w = _realService();

      final ok = await w.container
          .read(postOnboardingAuthControllerProvider.notifier)
          .signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(
        w.container.read(postOnboardingAuthControllerProvider).error,
        isA<OAuthCancelledException>(),
      );
      expect(w.report.faults, isEmpty);
      expect(w.report.degradeds, isEmpty);
      expect(
        w.analytics.findEvents(expectedFailureEvent).single.properties,
        {'area': 'auth', 'reason': 'oauth_cancelled'},
      );
    });

    test('Apple\'s unknown (1000) is exactly one report, with area auth, '
        'and no count', () async {
      messenger.setMockMethodCallHandler(_appleChannel, (call) async {
        throw PlatformException(
          code: 'authorization-error/unknown',
          message:
              'The operation couldn\'t be completed. '
              '(com.apple.AuthenticationServices.AuthorizationError error '
              '1000.)',
        );
      });
      final w = _realService();

      final ok = await w.container
          .read(postOnboardingAuthControllerProvider.notifier)
          .signInWithApple();
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      final reports = [...w.report.faults, ...w.report.degradeds];
      expect(reports, hasLength(1));
      expect(reports.single.area, 'auth');
      expect(
        reports.single.error,
        isA<SignInWithAppleAuthorizationException>(),
      );
      expect(w.analytics.findEvents(expectedFailureEvent), isEmpty);
    });
  });
}
