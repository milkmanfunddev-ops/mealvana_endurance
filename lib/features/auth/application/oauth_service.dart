import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../data/user_repository.dart';

part 'oauth_service.g.dart';

/// Service for handling OAuth account linking via native SDKs
/// Uses native Google Sign-In and Apple Sign-In packages
/// Exchanges native tokens with Supabase via signInWithIdToken
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
@riverpod
class OAuthService extends _$OAuthService {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);

  // Google Sign-In instance (lazy initialized)
  GoogleSignIn? _googleSignIn;

  @override
  FutureOr<void> build() {
    // Prevent Riverpod from disposing this provider during OAuth flow
    // Critical: OAuth may involve app backgrounding for native auth
    ref.keepAlive();

    // Log when provider is disposed for debugging
    ref.onDispose(() {
      _logger.info('OAuthService disposed', context: 'OAUTH_NATIVE');
    });
  }

  /// Initialize Google Sign-In with platform-specific configuration
  GoogleSignIn _getGoogleSignIn() {
    if (_googleSignIn != null) return _googleSignIn!;

    // Platform-specific client ID configuration
    // iOS: Uses GIDClientID from Info.plist
    // Android: Uses web client ID for server auth
    final clientId = Platform.isIOS
        ? null // iOS reads from Info.plist GIDClientID key
        : const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

    final serverClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

    _googleSignIn = GoogleSignIn(
      clientId: clientId,
      serverClientId: serverClientId,
      scopes: ['email', 'profile'],
    );

    return _googleSignIn!;
  }

  /// Link Apple account using native Apple Sign-In
  /// iOS 13+ required, uses AuthenticationServices framework
  Future<void> linkAppleAccount() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Apple Sign-In flow', context: 'OAUTH_NATIVE');

      // Track analytics
      await _analytics.track('auth_apple_native_started', properties: {
        'platform': Platform.operatingSystem,
      });

      // Get current user before linking
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link Apple account');
      }

      final anonymousUserId = currentUser.id;
      final wasAnonymous = currentUser.isAnonymous;

      _logger.info('Linking Apple account to user', context: 'OAUTH_NATIVE', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': wasAnonymous,
      });

      // Generate nonce for security
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // Launch native Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      _logger.info('Apple Sign-In credential received', context: 'OAUTH_NATIVE', data: {
        'has_identity_token': credential.identityToken != null,
        'email': credential.email,
      });

      // Exchange Apple credential for Supabase session
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce,
      );

      // Defensive check: ensure user ID didn't change (data preservation)
      if (response.user?.id != anonymousUserId) {
        _logger.error(
          'USER ID CHANGED during Apple linking - data may be lost!',
          context: 'OAUTH_NATIVE',
          data: {
            'expected_user_id': anonymousUserId,
            'actual_user_id': response.user?.id,
          },
        );
        throw Exception('User ID changed during account linking');
      }

      // Update local user profile with new auth provider
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: 'apple',
        isAnonymous: false,
      );

      _logger.info('Apple account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': response.user?.id,
      });

      // Track successful linking
      await _analytics.track('auth_apple_native_linked', properties: {
        'user_id': response.user?.id,
        'platform': Platform.operatingSystem,
      });
    });

    // Handle errors
    if (state.hasError) {
      final error = state.error;
      _logger.error('Apple Sign-In failed', context: 'OAUTH_NATIVE', error: error);

      // Distinguish user cancellation from errors
      final errorMessage = error.toString();
      final wasCancelled = errorMessage.contains("The operation couldn't be completed") ||
          errorMessage.contains('CANCELED') ||
          errorMessage.contains('1001'); // ASAuthorizationError.canceled

      await _analytics.track(
        wasCancelled ? 'auth_apple_native_cancelled' : 'auth_apple_native_failed',
        properties: {
          'error': errorMessage,
          'platform': Platform.operatingSystem,
        },
      );

      throw state.error!;
    }
  }

  /// Link Google account using native Google Sign-In
  /// Works on iOS and Android
  Future<void> linkGoogleAccount() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Google Sign-In flow', context: 'OAUTH_NATIVE');

      // Track analytics
      await _analytics.track('auth_google_native_started', properties: {
        'platform': Platform.operatingSystem,
      });

      // Get current user before linking
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link Google account');
      }

      final anonymousUserId = currentUser.id;
      final wasAnonymous = currentUser.isAnonymous;

      _logger.info('Linking Google account to user', context: 'OAUTH_NATIVE', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': wasAnonymous,
      });

      // Initialize Google Sign-In
      final googleSignIn = _getGoogleSignIn();

      // Sign out first to force account picker
      await googleSignIn.signOut();

      // Launch native Google Sign-In
      final GoogleSignInAccount? account = await googleSignIn.signIn();

      // User cancelled sign-in
      if (account == null) {
        _logger.info('Google Sign-In cancelled by user', context: 'OAUTH_NATIVE');
        await _analytics.track('auth_google_native_cancelled', properties: {
          'platform': Platform.operatingSystem,
        });
        throw Exception('Google Sign-In was cancelled');
      }

      _logger.info('Google Sign-In account selected', context: 'OAUTH_NATIVE', data: {
        'email': account.email,
      });

      // Get authentication tokens
      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null) {
        throw Exception('Google Sign-In failed: no ID token received');
      }

      _logger.info('Google authentication tokens received', context: 'OAUTH_NATIVE', data: {
        'has_id_token': auth.idToken != null,
        'has_access_token': auth.accessToken != null,
      });

      // Exchange Google tokens for Supabase session
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
        accessToken: auth.accessToken,
      );

      // Defensive check: ensure user ID didn't change (data preservation)
      if (response.user?.id != anonymousUserId) {
        _logger.error(
          'USER ID CHANGED during Google linking - data may be lost!',
          context: 'OAUTH_NATIVE',
          data: {
            'expected_user_id': anonymousUserId,
            'actual_user_id': response.user?.id,
          },
        );
        throw Exception('User ID changed during account linking');
      }

      // Update local user profile with new auth provider
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: 'google',
        isAnonymous: false,
      );

      _logger.info('Google account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': response.user?.id,
        'email': account.email,
      });

      // Track successful linking
      await _analytics.track('auth_google_native_linked', properties: {
        'user_id': response.user?.id,
        'email': account.email,
        'platform': Platform.operatingSystem,
      });
    });

    // Handle errors
    if (state.hasError) {
      final error = state.error;
      _logger.error('Google Sign-In failed', context: 'OAUTH_NATIVE', error: error);

      // Map Google Sign-In error codes
      final errorMessage = error.toString();
      final wasCancelled = errorMessage.contains('sign_in_canceled') ||
          errorMessage.contains('SIGN_IN_CANCELLED') ||
          errorMessage.contains('12501'); // Google Sign-In error code

      await _analytics.track(
        wasCancelled ? 'auth_google_native_cancelled' : 'auth_google_native_failed',
        properties: {
          'error': errorMessage,
          'platform': Platform.operatingSystem,
        },
      );

      throw state.error!;
    }
  }
}
