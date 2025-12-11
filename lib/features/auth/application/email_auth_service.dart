import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../../shared/services/preferences_service.dart';
import '../data/user_repository.dart';

part 'email_auth_service.g.dart';

/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
@riverpod
class EmailAuthService extends _$EmailAuthService {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;
  AnalyticsTracker get _analytics => ref.read(analyticsTrackerProvider);

  @override
  FutureOr<void> build() {
    // No initial state needed for this service
  }

  /// Link email/password to existing anonymous user
  /// Preserves the same auth.uid() and all existing user data
  Future<void> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting email account linking', context: 'EMAIL_AUTH', data: {
        'email_length': email.length,
        'password_length': password.length,
      });

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        throw Exception(emailValidation);
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation != null) {
        throw Exception(passwordValidation);
      }

      // Get current anonymous user before linking
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link email account');
      }

      final anonymousUserId = currentUser.id;
      _logger.info('Linking email account to user', context: 'EMAIL_AUTH', data: {
        'current_user_id': anonymousUserId,
        'is_anonymous': currentUser.isAnonymous,
      });

      // Update user with email and password
      // This converts the anonymous user to an email-authenticated user
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
        ),
      );

      if (response.user == null) {
        throw Exception('Email account linking failed - no user returned');
      }

      // Verify the user ID didn't change (critical for data preservation)
      if (response.user!.id != anonymousUserId) {
        _logger.error('User ID changed during linking', context: 'EMAIL_AUTH', data: {
          'old_id': anonymousUserId,
          'new_id': response.user!.id,
        });
        throw Exception('Account linking failed - user ID mismatch');
      }

      _logger.info('Email account linked successfully', context: 'EMAIL_AUTH', data: {
        'user_id': response.user!.id,
        'email': response.user!.email,
        'is_anonymous': response.user!.isAnonymous,
        'email_confirmed': response.user!.emailConfirmedAt != null,
      });

      // Complete authentication (unified flow for all providers)
      final userRepo = await ref.read(userRepositoryProvider.future);
      await userRepo.completeAuthentication(
        previousUserId: anonymousUserId,
        wasAnonymous: currentUser.isAnonymous,
        newUserId: anonymousUserId, // Same ID for linking
        authProvider: 'email',
        preservedUserId: true, // ID was preserved during linking
      );

      // Track successful linking in analytics
      await _analytics.track('email_account_linked', properties: {
        'user_id': response.user!.id,
        'email_confirmed': response.user!.emailConfirmedAt != null,
      });

      _logger.info('Email account linking complete', context: 'EMAIL_AUTH');

      // Note: Email confirmation is optional for faster onboarding
      // Users can still use the app immediately without confirming email
      if (response.user!.emailConfirmedAt == null) {
        _logger.info('Email confirmation pending (optional)', context: 'EMAIL_AUTH');
      }
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      _logger.error('Email account linking failed', context: 'EMAIL_AUTH', error: state.error);

      // Track failure in analytics
      await _analytics.track('email_account_linking_failed', properties: {
        'error': state.error.toString(),
      });

      throw state.error!;
    }
  }

  /// Sign in with email/password
  /// This will replace the current anonymous session with the email user's session
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info('Starting email sign in', context: 'EMAIL_AUTH', data: {
        'email_length': email.length,
      });

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        throw Exception(emailValidation);
      }

      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      // CRITICAL: Capture anonymous user ID BEFORE signing in
      // This allows us to migrate their data after the session switch
      final previousUserId = _supabase.auth.currentUser?.id;
      final wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      _logger.info('Capturing user state before sign-in', context: 'EMAIL_AUTH', data: {
        'previous_user_id': previousUserId,
        'was_anonymous': wasAnonymous,
      });

      // Sign in with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw Exception('Sign in failed - no session returned');
      }

      final newUserId = response.user!.id;

      _logger.info('Email sign in successful', context: 'EMAIL_AUTH', data: {
        'user_id': newUserId,
        'email': response.user!.email,
      });

      // Complete authentication (unified flow for all providers)
      final userRepo = await ref.read(userRepositoryProvider.future);
      final dataMigrated = await userRepo.completeAuthentication(
        previousUserId: previousUserId,
        wasAnonymous: wasAnonymous,
        newUserId: newUserId,
        authProvider: 'email',
        preservedUserId: false, // ID changed during sign-in
      );

      _logger.info('Sign-in completion handled', context: 'EMAIL_AUTH', data: {
        'data_migrated': dataMigrated,
      });

      // Track successful sign in
      await _analytics.track('email_sign_in_success', properties: {
        'user_id': newUserId,
        'migrated_data': dataMigrated,
      });

      // Trigger sync after sign-in to pull user data from Supabase
      // This is essential for new device logins where local DB is empty
      _logger.info('Triggering post-sign-in sync', context: 'EMAIL_AUTH', data: {
        'user_id': newUserId,
      });

      try {
        // CRITICAL: Clear sync timestamp to force full sync (not incremental)
        // Otherwise, if user logs out and back in on same device, we might send
        // an old timestamp and get no data back (because local DB was cleared)
        final prefs = await ref.read(sharedPreferencesProvider.future);
        await prefs.remove('last_sync_timestamp_$newUserId');

        await ref.read(syncCoordinatorProvider.notifier).sync(
          userId: newUserId,
          trigger: SyncTrigger.oauthSignIn,
        );
        _logger.info('Post-sign-in sync completed', context: 'EMAIL_AUTH');
      } catch (e) {
        _logger.error('Post-sign-in sync failed', context: 'EMAIL_AUTH', error: e);
        // Don't rethrow - sign-in was successful, user can pull-to-refresh
      }
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      _logger.error('Email sign in failed', context: 'EMAIL_AUTH', error: state.error);
      throw state.error!;
    }
  }

  /// Validate email format
  String? validateEmail(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null; // Valid
  }

  /// Validate password strength
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Optional: Add more validation rules
    // - Uppercase letter
    // - Number
    // - Special character

    return null; // Valid
  }
}
