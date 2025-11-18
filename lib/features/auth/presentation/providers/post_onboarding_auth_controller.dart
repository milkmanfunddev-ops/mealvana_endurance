import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/logging_service.dart';
import '../../application/oauth_service.dart';
import '../../application/email_auth_service.dart';

part 'post_onboarding_auth_controller.g.dart';

/// Controller for managing post-onboarding authentication flow
/// Handles native Apple Sign-In, native Google Sign-In, and Email/Password signup
@riverpod
class PostOnboardingAuthController extends _$PostOnboardingAuthController {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);
  OAuthService get _oauthService => ref.read(oAuthServiceProvider.notifier);
  EmailAuthService get _emailAuthService => ref.read(emailAuthServiceProvider.notifier);

  @override
  FutureOr<void> build() {
    // No initial state needed
  }

  /// Link Apple account using native Apple Sign-In
  Future<bool> linkAppleAccount() async {
    state = const AsyncLoading();

    _logger.info('Post-onboarding auth: Starting Apple Sign-In', context: 'AUTH');

    await _analytics.track('auth_flow_started', properties: {
      'provider': 'apple',
      'source': 'post_onboarding',
    });

    state = await AsyncValue.guard(() async {
      await _oauthService.linkAppleAccount();
    });

    if (state.hasError) {
      _logger.error('Post-onboarding auth: Apple Sign-In failed',
        context: 'AUTH',
        error: state.error,
      );

      await _analytics.track('auth_flow_failed', properties: {
        'provider': 'apple',
        'source': 'post_onboarding',
        'error': state.error.toString(),
      });
    } else {
      _logger.info('Post-onboarding auth: Apple Sign-In completed successfully', context: 'AUTH');

      await _analytics.track('auth_flow_completed', properties: {
        'provider': 'apple',
        'source': 'post_onboarding',
      });
    }

    return !state.hasError;
  }

  /// Link Google account using native Google Sign-In
  Future<bool> linkGoogleAccount() async {
    state = const AsyncLoading();

    _logger.info('Post-onboarding auth: Starting Google Sign-In', context: 'AUTH');

    await _analytics.track('auth_flow_started', properties: {
      'provider': 'google',
      'source': 'post_onboarding',
    });

    state = await AsyncValue.guard(() async {
      await _oauthService.linkGoogleAccount();
    });

    if (state.hasError) {
      _logger.error('Post-onboarding auth: Google Sign-In failed',
        context: 'AUTH',
        error: state.error,
      );

      await _analytics.track('auth_flow_failed', properties: {
        'provider': 'google',
        'source': 'post_onboarding',
        'error': state.error.toString(),
      });
    } else {
      _logger.info('Post-onboarding auth: Google Sign-In completed successfully', context: 'AUTH');

      await _analytics.track('auth_flow_completed', properties: {
        'provider': 'google',
        'source': 'post_onboarding',
      });
    }

    return !state.hasError;
  }

  /// Link email/password account
  Future<bool> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    _logger.info('Post-onboarding auth: Starting email account creation', context: 'AUTH');

    await _analytics.track('auth_flow_started', properties: {
      'provider': 'email',
      'source': 'post_onboarding',
    });

    state = await AsyncValue.guard(() async {
      await _emailAuthService.linkEmailAccount(
        email: email,
        password: password,
      );
    });

    if (state.hasError) {
      _logger.error('Post-onboarding auth: Email account creation failed',
        context: 'AUTH',
        error: state.error,
      );

      await _analytics.track('auth_flow_failed', properties: {
        'provider': 'email',
        'source': 'post_onboarding',
        'error': state.error.toString(),
      });
    } else {
      _logger.info('Post-onboarding auth: Email account created successfully', context: 'AUTH');

      await _analytics.track('auth_flow_completed', properties: {
        'provider': 'email',
        'source': 'post_onboarding',
      });
    }

    return !state.hasError;
  }

  /// Track when user skips authentication
  Future<void> skipAuthentication() async {
    _logger.info('Post-onboarding auth: User skipped authentication', context: 'AUTH');

    await _analytics.track('auth_skipped', properties: {
      'source': 'post_onboarding',
    });
  }
}
