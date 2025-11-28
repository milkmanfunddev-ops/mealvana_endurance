import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
// Explicitly import AuthException to use it in catch blocks
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../data/user_repository.dart';
import '../domain/auth_exceptions.dart';

part 'oauth_service.g.dart';

/// Service for handling OAuth account linking via native SDKs
/// Uses native Google Sign-In and Apple Sign-In packages
/// Links OAuth identities to existing anonymous users via linkIdentityWithIdToken()
/// Preserves user ID and all user data during account linking
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

      try {
        // Link Apple identity to current user (preserves user ID)
        final response = await _supabase.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.identityToken!,
          nonce: rawNonce,
        );

        // Verify user ID was preserved (should never change with linkIdentityWithIdToken)
        if (response.user?.id != anonymousUserId) {
          _logger.error(
            'USER ID CHANGED during Apple linking - unexpected behavior!',
            context: 'OAUTH_NATIVE',
            data: {
              'expected_user_id': anonymousUserId,
              'actual_user_id': response.user?.id,
            },
          );
          throw Exception('User ID changed unexpectedly during linking');
        }
      } on supabase.AuthException catch (e) {
        if (e.message.contains('already linked') || e.message.contains('Identity is already linked')) {
          _logger.warning('Apple account already linked to another user', context: 'OAUTH_NATIVE');
          throw AccountAlreadyExistsException(
            'This Apple account is already linked to another user.',
            email: credential.email,
          );
        }
        rethrow;
      }

      // Update local user profile with new auth provider
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: 'apple',
        isAnonymous: false,
      );

      _logger.info('Apple account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': anonymousUserId,
      });

      // Track successful linking
      await _analytics.track('auth_apple_native_linked', properties: {
        'user_id': anonymousUserId,
        'platform': Platform.operatingSystem,
      });
    });

    // Handle errors
    if (state.hasError) {
      final error = state.error;
      // Don't log expected exceptions as errors
      if (error is AccountAlreadyExistsException) {
        throw error;
      }
      
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

      try {
        // Link Google identity to current user (preserves user ID)
        final response = await _supabase.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: auth.idToken!,
          accessToken: auth.accessToken,
        );

        // Verify user ID was preserved (should never change with linkIdentityWithIdToken)
        if (response.user?.id != anonymousUserId) {
          _logger.error(
            'USER ID CHANGED during Google linking - unexpected behavior!',
            context: 'OAUTH_NATIVE',
            data: {
              'expected_user_id': anonymousUserId,
              'actual_user_id': response.user?.id,
            },
          );
          throw Exception('User ID changed unexpectedly during linking');
        }
      } on supabase.AuthException catch (e) {
        if (e.message.contains('already linked') || e.message.contains('Identity is already linked')) {
          _logger.warning('Google account already linked to another user', context: 'OAUTH_NATIVE');
          throw AccountAlreadyExistsException(
            'This Google account is already linked to another user.',
            email: account.email,
          );
        }
        rethrow;
      }

      // Update local user profile with new auth provider
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.updateAuthProvider(
        authProvider: 'google',
        isAnonymous: false,
      );

      _logger.info('Google account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': anonymousUserId,
        'email': account.email,
      });

      // Track successful linking
      await _analytics.track('auth_google_native_linked', properties: {
        'user_id': anonymousUserId,
        'email': account.email,
        'platform': Platform.operatingSystem,
      });
    });

    // Handle errors
    if (state.hasError) {
      final error = state.error;
      // Don't log expected exceptions as errors
      if (error is AccountAlreadyExistsException) {
        throw error;
      }

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

  /// Sign in with Apple (replaces current anonymous user)
  /// Used when account linking fails because account already exists
  /// Migrates anonymous user's data to the existing OAuth account
  Future<void> signInWithApple() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Apple Sign-In (Sign In mode)', context: 'OAUTH_NATIVE');

      await _analytics.track('auth_apple_signin_started', properties: {
        'platform': Platform.operatingSystem,
      });

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      final anonymousUserId = _supabase.auth.currentUser?.id;
      final wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      _logger.info('Capturing anonymous user before sign-in', context: 'OAUTH_NATIVE', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
      });

      // Generate nonce
      final rawNonce = _supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // Native Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      // Sign in (switches session to this user)
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: rawNonce,
      );

      final oauthUserId = response.user?.id;

      _logger.info('Apple Sign-In successful (session switched)', context: 'OAUTH_NATIVE', data: {
        'user_id': oauthUserId,
      });

      // CRITICAL: Migrate anonymous user's data to the OAuth account
      if (anonymousUserId != null && oauthUserId != null && anonymousUserId != oauthUserId) {
        _logger.info('Migrating anonymous user data to OAuth account', context: 'OAUTH_NATIVE', data: {
          'from_anonymous_user_id': anonymousUserId,
          'to_oauth_user_id': oauthUserId,
        });

        final userRepo = await ref.read(userRepositoryProvider.future);
        await userRepo.migrateAnonymousUserData(
          fromAnonymousUserId: anonymousUserId,
          toOAuthUserId: oauthUserId,
          authProvider: 'apple',
        );

        _logger.info('Data migration completed successfully', context: 'OAUTH_NATIVE');
      }

      await _analytics.track('auth_apple_signin_completed', properties: {
        'user_id': oauthUserId,
        'platform': Platform.operatingSystem,
        'migrated_data': anonymousUserId != null && anonymousUserId != oauthUserId,
      });
    });

    if (state.hasError) {
      _logger.error('Apple Sign-In failed', context: 'OAUTH_NATIVE', error: state.error);
      throw state.error!;
    }
  }

  /// Sign in with Google (replaces current anonymous user)
  /// Used when account linking fails because account already exists
  /// Migrates anonymous user's data to the existing OAuth account
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Google Sign-In (Sign In mode)', context: 'OAUTH_NATIVE');

      await _analytics.track('auth_google_signin_started', properties: {
        'platform': Platform.operatingSystem,
      });

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      final anonymousUserId = _supabase.auth.currentUser?.id;
      final wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      _logger.info('Capturing anonymous user before sign-in', context: 'OAUTH_NATIVE', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
      });

      final googleSignIn = _getGoogleSignIn();
      await googleSignIn.signOut(); // Force picker

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        throw Exception('Google Sign-In cancelled');
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      if (auth.idToken == null) {
        throw Exception('Google Sign-In failed: no ID token received');
      }

      // Sign in (switches session to this user)
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: auth.idToken!,
        accessToken: auth.accessToken,
      );

      final oauthUserId = response.user?.id;

      _logger.info('Google Sign-In successful (session switched)', context: 'OAUTH_NATIVE', data: {
        'user_id': oauthUserId,
      });

      // CRITICAL: Migrate anonymous user's data to the OAuth account
      if (anonymousUserId != null && oauthUserId != null && anonymousUserId != oauthUserId) {
        _logger.info('Migrating anonymous user data to OAuth account', context: 'OAUTH_NATIVE', data: {
          'from_anonymous_user_id': anonymousUserId,
          'to_oauth_user_id': oauthUserId,
        });

        final userRepo = await ref.read(userRepositoryProvider.future);
        await userRepo.migrateAnonymousUserData(
          fromAnonymousUserId: anonymousUserId,
          toOAuthUserId: oauthUserId,
          authProvider: 'google',
        );

        _logger.info('Data migration completed successfully', context: 'OAUTH_NATIVE');
      }

      await _analytics.track('auth_google_signin_completed', properties: {
        'user_id': oauthUserId,
        'platform': Platform.operatingSystem,
        'migrated_data': anonymousUserId != null && anonymousUserId != oauthUserId,
      });
    });

    if (state.hasError) {
      _logger.error('Google Sign-In failed', context: 'OAUTH_NATIVE', error: state.error);
      throw state.error!;
    }
  }
}
