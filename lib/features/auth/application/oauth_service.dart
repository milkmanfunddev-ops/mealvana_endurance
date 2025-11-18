import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_service.dart';
import '../../../shared/services/logging_service.dart';
import '../data/user_repository.dart';

part 'oauth_service.g.dart';

/// Service for handling OAuth account linking via Supabase web flow
/// Uses Supabase's hosted OAuth (no native dependencies required)
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
@riverpod
class OAuthService extends _$OAuthService {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;
  AnalyticsService get _analytics => ref.read(analyticsServiceProvider);

  // Deep link redirect for OAuth callbacks
  static const String redirectUrl = 'com.milkman.mealvanaendurance://auth-callback';

  @override
  FutureOr<void> build() {
    // No initial state needed for this service
  }

  /// Link Apple account using Supabase web OAuth
  /// Opens browser for Apple Sign-In, redirects back to app
  Future<void> linkAppleAccount() async {
    await _linkOAuthProvider(
      provider: OAuthProvider.apple,
      providerName: 'Apple',
    );
  }

  /// Link Google account using Supabase web OAuth
  /// Opens browser for Google Sign-In, redirects back to app
  Future<void> linkGoogleAccount() async {
    await _linkOAuthProvider(
      provider: OAuthProvider.google,
      providerName: 'Google',
    );
  }

  /// Generic OAuth linking method for any provider
  Future<void> _linkOAuthProvider({
    required OAuthProvider provider,
    required String providerName,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting $providerName OAuth flow', context: 'OAUTH', data: {
        'provider': provider.name,
      });

      // Get current anonymous user before linking
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link $providerName account');
      }

      final anonymousUserId = currentUser.id;
      final wasAnonymous = currentUser.isAnonymous ?? true;

      _logger.info('Linking $providerName account to user', context: 'OAUTH', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': wasAnonymous,
        'provider': provider.name,
      });

      // Launch Supabase web OAuth flow
      // This opens browser/web view, user signs in, then redirects back to app
      final result = await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication, // Opens in browser
      );

      if (!result) {
        throw Exception('$providerName OAuth flow was cancelled or failed');
      }

      _logger.info('$providerName OAuth flow initiated', context: 'OAUTH', data: {
        'redirect_url': redirectUrl,
      });

      // Note: The actual account linking happens when the redirect callback fires
      // The auth state change listener (in app startup) will detect the new session
      // and update the local profile accordingly

      // For now, we track that the flow was started
      await _analytics.track('oauth_flow_started', properties: {
        'provider': provider.name,
        'user_id': anonymousUserId,
      });

      // The completion will be handled by the auth state change listener
      // See: app_startup_service.dart -> setupAuthStateListener()
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      _logger.error('OAuth linking failed', context: 'OAUTH', error: state.error);

      await _analytics.track('oauth_linking_failed', properties: {
        'error': state.error.toString(),
        'provider': provider.name,
      });

      throw state.error!;
    }
  }

  /// Handle OAuth callback after successful sign-in
  /// This is called by the app startup service when auth state changes
  Future<void> handleOAuthCallback({
    required String userId,
    required String provider,
  }) async {
    try {
      _logger.info('Handling OAuth callback', context: 'OAUTH', data: {
        'user_id': userId,
        'provider': provider,
      });

      // Update local user profile with new auth provider
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: provider,
        isAnonymous: false,
      );

      // Track successful linking in analytics
      await _analytics.track('oauth_account_linked', properties: {
        'user_id': userId,
        'provider': provider,
      });

      _logger.info('OAuth account linking complete', context: 'OAUTH', data: {
        'user_id': userId,
        'provider': provider,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to handle OAuth callback', context: 'OAUTH', error: e);
      await _analytics.track('oauth_callback_failed', properties: {
        'error': e.toString(),
        'provider': provider,
      });
      rethrow;
    }
  }
}
