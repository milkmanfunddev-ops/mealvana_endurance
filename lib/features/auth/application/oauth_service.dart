import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
// Explicitly import AuthException and LaunchMode to use in catch blocks and web OAuth
import 'package:supabase_flutter/supabase_flutter.dart' as supabase show AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/utils/platform_io.dart' if (dart.library.html) '../../../shared/utils/platform_web.dart';
import '../../activities/presentation/providers/activities_controller.dart';
import '../../events/presentation/providers/events_controller.dart';
import '../domain/auth_exceptions.dart';
import 'auth_migration_service.dart';

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

    // Web platforms use Supabase's web OAuth flow, not native Google Sign-In
    if (kIsWeb) {
      throw UnsupportedError('Native Google Sign-In not supported on web. Use Supabase web OAuth flow.');
    }

    // Web Client ID - used as serverClientId to get ID token for Supabase
    const webClientId = '171527646530-d1hr8a9ja4ucqk28cipcfnlo288qhccn.apps.googleusercontent.com';

    // Android Client ID for prod flavor (Mealvana Android Release)
    // Prod flavor always signs with the release keystore (see build.gradle.kts),
    // so one OAuth client covers both debug and release builds.
    // SHA-1: AB:86:C5:24:4D:DE:3E:75:40:65:B4:1D:7F:FC:61:CB:10:05:7A:0D
    const androidClientId = '171527646530-5sjjs6che5nsl7nom9l8cfh64087aitb.apps.googleusercontent.com';

    _logger.info('Initializing Google Sign-In', context: 'OAUTH_NATIVE', data: {
      'platform': PlatformInfo.operatingSystem,
    });

    _googleSignIn = GoogleSignIn(
      clientId: PlatformInfo.isIOS ? null : androidClientId,
      serverClientId: webClientId,
      scopes: ['email', 'profile'],
    );

    return _googleSignIn!;
  }

  /// Link Apple account using native Apple Sign-In (mobile) or Supabase OAuth (web)
  /// iOS 13+ required for native, uses AuthenticationServices framework
  Future<void> linkAppleAccount() async {
    // Web platforms use Supabase's web OAuth flow
    if (kIsWeb) {
      return _linkAppleAccountWeb();
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Apple Sign-In flow', context: 'OAUTH_NATIVE');

      // Track analytics
      await _analytics.track('auth_apple_native_started', properties: {
        'platform': PlatformInfo.operatingSystem,
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

      // Complete authentication (unified flow for all providers)
      final authMigrationService = await ref.read(authMigrationServiceProvider.future);
      await authMigrationService.completeAuthentication(
        previousUserId: anonymousUserId,
        wasAnonymous: wasAnonymous,
        newUserId: anonymousUserId, // Same ID for linking
        authProvider: 'apple',
        preservedUserId: true, // ID was preserved during linking
      );

      _logger.info('Apple account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': anonymousUserId,
      });

      // Track successful linking
      await _analytics.track('auth_apple_native_linked', properties: {
        'user_id': anonymousUserId,
        'platform': PlatformInfo.operatingSystem,
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
          'platform': PlatformInfo.operatingSystem,
        },
      );

      throw state.error!;
    }
  }

  /// Link Google account using native Google Sign-In (mobile) or Supabase OAuth (web)
  /// Works on iOS, Android, and Web
  Future<void> linkGoogleAccount() async {
    // Web platforms use Supabase's web OAuth flow
    if (kIsWeb) {
      return _linkGoogleAccountWeb();
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Google Sign-In flow', context: 'OAUTH_NATIVE');

      // Track analytics
      await _analytics.track('auth_google_native_started', properties: {
        'platform': PlatformInfo.operatingSystem,
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
          'platform': PlatformInfo.operatingSystem,
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

      // Complete authentication (unified flow for all providers)
      final authMigrationService = await ref.read(authMigrationServiceProvider.future);
      await authMigrationService.completeAuthentication(
        previousUserId: anonymousUserId,
        wasAnonymous: wasAnonymous,
        newUserId: anonymousUserId, // Same ID for linking
        authProvider: 'google',
        preservedUserId: true, // ID was preserved during linking
      );

      _logger.info('Google account linked successfully', context: 'OAUTH_NATIVE', data: {
        'user_id': anonymousUserId,
        'email': account.email,
      });

      // Track successful linking
      await _analytics.track('auth_google_native_linked', properties: {
        'user_id': anonymousUserId,
        'email': account.email,
        'platform': PlatformInfo.operatingSystem,
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
          'platform': PlatformInfo.operatingSystem,
        },
      );

      throw state.error!;
    }
  }

  /// Sign in with Apple (replaces current anonymous user)
  /// Used when account linking fails because account already exists
  /// Migrates anonymous user's data to the existing OAuth account
  Future<void> signInWithApple() async {
    // Web platforms use Supabase's web OAuth flow
    if (kIsWeb) {
      return _signInWithAppleWeb();
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Apple Sign-In (Sign In mode)', context: 'OAUTH_NATIVE');

      await _analytics.track('auth_apple_signin_started', properties: {
        'platform': PlatformInfo.operatingSystem,
      });

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      var anonymousUserId = _supabase.auth.currentUser?.id;
      var wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      // Also check for temp onboarding user ID (used when no Supabase session exists)
      final prefs = ref.read(sharedPreferencesProvider);
      final tempUserId = prefs.getString('onboarding_temp_user_id');
      if (anonymousUserId == null && tempUserId != null) {
        anonymousUserId = tempUserId;
        wasAnonymous = true;
      }

      _logger.info('Capturing anonymous user before sign-in', context: 'OAUTH_NATIVE', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
        'had_temp_user_id': tempUserId != null,
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

      // CRITICAL: Complete authentication (migration + profile update)
      if (oauthUserId != null) {
        _logger.info('Completing authentication', context: 'OAUTH_NATIVE', data: {
          'previous_user_id': anonymousUserId,
          'new_user_id': oauthUserId,
          'was_anonymous': wasAnonymous,
        });

        final authMigrationService = await ref.read(authMigrationServiceProvider.future);
        final dataMigrated = await authMigrationService.completeAuthentication(
          previousUserId: anonymousUserId,
          wasAnonymous: wasAnonymous,
          newUserId: oauthUserId,
          authProvider: 'apple',
          preservedUserId: false, // ID changed during sign-in
        );

        _logger.info('Authentication completed', context: 'OAUTH_NATIVE', data: {
          'data_migrated': dataMigrated,
        });

        // Clear temp user ID after successful migration
        if (tempUserId != null) {
          await prefs.remove('onboarding_temp_user_id');
          _logger.info('Cleared onboarding temp user ID after Apple sign-in', context: 'OAUTH_NATIVE');
        }
      }

      await _analytics.track('auth_apple_signin_completed', properties: {
        'user_id': oauthUserId,
        'platform': PlatformInfo.operatingSystem,
        'migrated_data': anonymousUserId != null && anonymousUserId != oauthUserId,
      });

      // CRITICAL: Explicitly trigger full sync after sign-in
      if (oauthUserId != null) {
        _logger.info('Triggering post-sign-in sync', context: 'OAUTH_NATIVE', data: {
          'user_id': oauthUserId,
        });

        try {
          // Clear sync timestamp to force full sync (not incremental)
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.remove('last_sync_timestamp_$oauthUserId');

          // Trigger sync using SyncCoordinator (provides sync lock and logging)
          await ref.read(syncCoordinatorProvider.notifier).sync(
            userId: oauthUserId,
            trigger: SyncTrigger.oauthSignIn,
            skipInvalidation: true,
          );

          // Invalidate providers so UI reflects synced data
          ref.invalidate(userIdProvider);
          ref.invalidate(activitiesControllerProvider);
          ref.invalidate(allEventsProvider);
          ref.invalidate(nextUpcomingEventProvider);

          _logger.info('Post-sign-in sync completed - providers invalidated', context: 'OAUTH_NATIVE');
        } catch (e) {
          _logger.error('Post-sign-in sync failed', context: 'OAUTH_NATIVE', error: e);
          // Don't rethrow - sign-in was successful, sync can be retried
        }
      }
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
    // Web platforms use Supabase's web OAuth flow
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting native Google Sign-In (Sign In mode)', context: 'OAUTH_NATIVE');

      await _analytics.track('auth_google_signin_started', properties: {
        'platform': PlatformInfo.operatingSystem,
      });

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      var anonymousUserId = _supabase.auth.currentUser?.id;
      var wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      // Also check for temp onboarding user ID (used when no Supabase session exists)
      final prefs = ref.read(sharedPreferencesProvider);
      final tempUserId = prefs.getString('onboarding_temp_user_id');
      if (anonymousUserId == null && tempUserId != null) {
        anonymousUserId = tempUserId;
        wasAnonymous = true;
      }

      _logger.info('Capturing anonymous user before sign-in', context: 'OAUTH_NATIVE', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
        'had_temp_user_id': tempUserId != null,
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

      // CRITICAL: Only migrate data if:
      // 1. We had an anonymous user before sign-in
      // 2. That user was actually anonymous (not an OAuth user who signed out)
      // 3. The anonymous user has data worth migrating (activities, events, etc.)
      //
      // DO NOT migrate if:
      // - User is signing back into their existing OAuth account after sign-out
      // - The "anonymous" user was just created during sign-out and has no data
      //
      // This prevents the bug where signing back in deletes all user data
      if (oauthUserId != null) {
        _logger.info('Completing authentication', context: 'OAUTH_NATIVE', data: {
          'previous_user_id': anonymousUserId,
          'new_user_id': oauthUserId,
          'was_anonymous': wasAnonymous,
        });

        final authMigrationService = await ref.read(authMigrationServiceProvider.future);
        final dataMigrated = await authMigrationService.completeAuthentication(
          previousUserId: anonymousUserId,
          wasAnonymous: wasAnonymous,
          newUserId: oauthUserId,
          authProvider: 'google',
          preservedUserId: false, // ID changed during sign-in
        );

        _logger.info('Authentication completed', context: 'OAUTH_NATIVE', data: {
          'data_migrated': dataMigrated,
        });

        // Clear temp user ID after successful migration
        if (tempUserId != null) {
          await prefs.remove('onboarding_temp_user_id');
          _logger.info('Cleared onboarding temp user ID after Google sign-in', context: 'OAUTH_NATIVE');
        }
      }

      await _analytics.track('auth_google_signin_completed', properties: {
        'user_id': oauthUserId,
        'platform': PlatformInfo.operatingSystem,
        'migrated_data': anonymousUserId != null && anonymousUserId != oauthUserId,
      });

      // CRITICAL: Explicitly trigger full sync after sign-in
      // The auth state listener may not fire reliably, so we trigger sync directly
      // Clear any stale sync timestamp first to force a FULL sync
      if (oauthUserId != null) {
        _logger.info('Triggering post-sign-in sync', context: 'OAUTH_NATIVE', data: {
          'user_id': oauthUserId,
        });

        try {
          // Clear sync timestamp to force full sync (not incremental)
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.remove('last_sync_timestamp_$oauthUserId');

          // Trigger sync using SyncCoordinator (provides sync lock and logging)
          // Note: We pass skipInvalidation=true and handle invalidation ourselves
          // to maintain the exact same timing as the original inline code
          await ref.read(syncCoordinatorProvider.notifier).sync(
            userId: oauthUserId,
            trigger: SyncTrigger.oauthSignIn,
            skipInvalidation: true,
          );

          // Invalidate providers so UI reflects synced data
          // Done inline here (not in SyncCoordinator) to maintain original timing
          ref.invalidate(userIdProvider);
          ref.invalidate(activitiesControllerProvider);
          ref.invalidate(allEventsProvider);
          ref.invalidate(nextUpcomingEventProvider);

          _logger.info('Post-sign-in sync completed - providers invalidated', context: 'OAUTH_NATIVE');
        } catch (e) {
          _logger.error('Post-sign-in sync failed', context: 'OAUTH_NATIVE', error: e);
          // Don't rethrow - sign-in was successful, sync can be retried
        }
      }
    });

    if (state.hasError) {
      _logger.error('Google Sign-In failed', context: 'OAUTH_NATIVE', error: state.error);
      throw state.error!;
    }
  }

  // ============================================================================
  // WEB OAUTH METHODS
  // These methods use Supabase's built-in OAuth flow for web platforms
  // ============================================================================

  /// Get the redirect URL for OAuth callbacks on web
  /// Uses the current window location for local development
  String _getWebRedirectUrl() {
    // For web, we need to redirect back to our app after OAuth
    // In production, this should be your deployed URL
    // In development, this is typically localhost
    return Uri.base.origin;
  }

  /// Link Apple account using Supabase web OAuth flow
  Future<void> _linkAppleAccountWeb() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting web Apple OAuth flow (linking)', context: 'OAUTH_WEB');

      await _analytics.track('auth_apple_web_started', properties: {
        'platform': 'web',
        'mode': 'link',
      });

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link Apple account');
      }

      final anonymousUserId = currentUser.id;
      final wasAnonymous = currentUser.isAnonymous;

      _logger.info('Linking Apple account to user (web)', context: 'OAUTH_WEB', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': wasAnonymous,
      });

      try {
        // Use Supabase's linkIdentity for web OAuth linking
        await _supabase.auth.linkIdentity(
          OAuthProvider.apple,
          redirectTo: _getWebRedirectUrl(),
          authScreenLaunchMode: LaunchMode.platformDefault, // Use platform default for web
        );

        // Note: The OAuth flow will redirect the browser, so we won't reach this
        // point immediately. The auth state change listener will handle the result.
        _logger.info('Apple OAuth redirect initiated', context: 'OAUTH_WEB');
      } on supabase.AuthException catch (e) {
        if (e.message.contains('already linked') || e.message.contains('Identity is already linked')) {
          _logger.warning('Apple account already linked to another user (web)', context: 'OAUTH_WEB');
          throw AccountAlreadyExistsException(
            'This Apple account is already linked to another user.',
            email: null,
          );
        }
        rethrow;
      }
    });

    if (state.hasError) {
      final error = state.error;
      if (error is AccountAlreadyExistsException) {
        throw error;
      }
      _logger.error('Apple web OAuth failed', context: 'OAUTH_WEB', error: error);
      throw state.error!;
    }
  }

  /// Link Google account using Supabase web OAuth flow
  Future<void> _linkGoogleAccountWeb() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting web Google OAuth flow (linking)', context: 'OAUTH_WEB');

      await _analytics.track('auth_google_web_started', properties: {
        'platform': 'web',
        'mode': 'link',
      });

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link Google account');
      }

      final anonymousUserId = currentUser.id;
      final wasAnonymous = currentUser.isAnonymous;

      _logger.info('Linking Google account to user (web)', context: 'OAUTH_WEB', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': wasAnonymous,
      });

      try {
        // Use Supabase's linkIdentity for web OAuth linking
        await _supabase.auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: _getWebRedirectUrl(),
          authScreenLaunchMode: LaunchMode.platformDefault, // Use platform default for web
        );

        // Note: The OAuth flow will redirect the browser, so we won't reach this
        // point immediately. The auth state change listener will handle the result.
        _logger.info('Google OAuth redirect initiated', context: 'OAUTH_WEB');
      } on supabase.AuthException catch (e) {
        if (e.message.contains('already linked') || e.message.contains('Identity is already linked')) {
          _logger.warning('Google account already linked to another user (web)', context: 'OAUTH_WEB');
          throw AccountAlreadyExistsException(
            'This Google account is already linked to another user.',
            email: null,
          );
        }
        rethrow;
      }
    });

    if (state.hasError) {
      final error = state.error;
      if (error is AccountAlreadyExistsException) {
        throw error;
      }
      _logger.error('Google web OAuth failed', context: 'OAUTH_WEB', error: error);
      throw state.error!;
    }
  }

  /// Sign in with Apple using Supabase web OAuth flow
  Future<void> _signInWithAppleWeb() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting web Apple OAuth flow (sign-in)', context: 'OAUTH_WEB');

      await _analytics.track('auth_apple_web_signin_started', properties: {
        'platform': 'web',
      });

      // Capture current user ID for potential data migration
      final anonymousUserId = _supabase.auth.currentUser?.id;
      final wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      _logger.info('Capturing anonymous user before web sign-in', context: 'OAUTH_WEB', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
      });

      // Use Supabase's signInWithOAuth for web sign-in
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _getWebRedirectUrl(),
        authScreenLaunchMode: LaunchMode.platformDefault, // Use platform default for web
      );

      // Note: The OAuth flow will redirect the browser, so we won't reach this
      // point immediately. The auth state change listener will handle the result.
      _logger.info('Apple OAuth sign-in redirect initiated', context: 'OAUTH_WEB');
    });

    if (state.hasError) {
      _logger.error('Apple web OAuth sign-in failed', context: 'OAUTH_WEB', error: state.error);
      throw state.error!;
    }
  }

  /// Sign in with Google using Supabase web OAuth flow
  Future<void> _signInWithGoogleWeb() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting web Google OAuth flow (sign-in)', context: 'OAUTH_WEB');

      await _analytics.track('auth_google_web_signin_started', properties: {
        'platform': 'web',
      });

      // Capture current user ID for potential data migration
      final anonymousUserId = _supabase.auth.currentUser?.id;
      final wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      _logger.info('Capturing anonymous user before web sign-in', context: 'OAUTH_WEB', data: {
        'anonymous_user_id': anonymousUserId,
        'was_anonymous': wasAnonymous,
      });

      // Use Supabase's signInWithOAuth for web sign-in
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getWebRedirectUrl(),
        authScreenLaunchMode: LaunchMode.platformDefault, // Use platform default for web
      );

      // Note: The OAuth flow will redirect the browser, so we won't reach this
      // point immediately. The auth state change listener will handle the result.
      _logger.info('Google OAuth sign-in redirect initiated', context: 'OAUTH_WEB');
    });

    if (state.hasError) {
      _logger.error('Google web OAuth sign-in failed', context: 'OAUTH_WEB', error: state.error);
      throw state.error!;
    }
  }
}
