import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../domain/auth_exceptions.dart';
import 'auth_migration_service.dart';

part 'email_auth_service.g.dart';

/// Service for handling Email/Password authentication
/// Uses Supabase's built-in updateUser() to link email to anonymous account
/// Follows Andrea Bizzotto's AsyncNotifier pattern with @riverpod
@riverpod
class EmailAuthService extends _$EmailAuthService {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseClient get _supabase =>
      ref.read(appExternalDepsProvider).supabaseClient;
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
      // Defensive check - this should never happen but adding for safety
      if (email.isEmpty || password.isEmpty) {
        _logger.error(
          'Empty email or password received',
          context: 'EMAIL_AUTH',
          data: {
            'email_length': email.length,
            'password_length': password.length,
            'email_value': email,
          },
        );
        throw Exception('Email and password are required');
      }

      _logger.info(
        'Starting email account linking',
        context: 'EMAIL_AUTH',
        data: {
          'email_length': email.length,
          'email_value': email,
          'password_length': password.length,
        },
      );

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        _logger.error(
          'Email validation failed',
          context: 'EMAIL_AUTH',
          data: {'email': email, 'validation_error': emailValidation},
        );
        throw Exception(emailValidation);
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation != null) {
        _logger.error(
          'Password validation failed',
          context: 'EMAIL_AUTH',
          data: {'validation_error': passwordValidation},
        );
        throw Exception(passwordValidation);
      }

      // Get current anonymous user before linking
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No active auth session - cannot link email account');
      }

      final anonymousUserId = currentUser.id;
      _logger.info(
        'Linking email account to user',
        context: 'EMAIL_AUTH',
        data: {
          'current_user_id': anonymousUserId,
          'is_anonymous': currentUser.isAnonymous,
        },
      );

      // CRITICAL: Supabase requires a two-step process for anonymous users:
      // 1. First update with email only
      // 2. Then update with password
      // If done in one step, email gets stripped (known Supabase behavior)

      _logger.info(
        'Step 1: Setting email address',
        context: 'EMAIL_AUTH',
        data: {
          'email': email,
          'email_is_empty': email.isEmpty,
          'email_length': email.length,
        },
      );

      // Create UserAttributes and log what will be sent
      final userAttributes = UserAttributes(email: email);

      _logger.info(
        'Step 1: UserAttributes created',
        context: 'EMAIL_AUTH',
        data: {
          'attributes_json': userAttributes.toJson(),
          'email_param': email,
        },
      );

      // Step 1: Update user with email only
      final emailResponse = await _supabase.auth.updateUser(userAttributes);

      if (emailResponse.user == null) {
        throw Exception('Email linking failed - no user returned');
      }

      _logger.info(
        'Step 1 complete: Email set successfully',
        context: 'EMAIL_AUTH',
        data: {
          'user_id': emailResponse.user!.id,
          'email': emailResponse.user!.email,
        },
      );

      // Step 2: Update user with password
      _logger.info('Step 2: Setting password', context: 'EMAIL_AUTH');

      final response = await _supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      if (response.user == null) {
        throw Exception('Password linking failed - no user returned');
      }

      _logger.info(
        'Step 2 complete: Password set successfully',
        context: 'EMAIL_AUTH',
      );

      // Verify the user ID didn't change (critical for data preservation)
      if (response.user!.id != anonymousUserId) {
        _logger.error(
          'User ID changed during linking',
          context: 'EMAIL_AUTH',
          data: {'old_id': anonymousUserId, 'new_id': response.user!.id},
        );
        throw Exception('Account linking failed - user ID mismatch');
      }

      _logger.info(
        'Email account linked successfully',
        context: 'EMAIL_AUTH',
        data: {
          'user_id': response.user!.id,
          'email': response.user!.email,
          'is_anonymous': response.user!.isAnonymous,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      // Complete authentication (unified flow for all providers)
      final authMigrationService = await ref.read(
        authMigrationServiceProvider.future,
      );
      await authMigrationService.completeAuthentication(
        previousUserId: anonymousUserId,
        wasAnonymous: currentUser.isAnonymous,
        newUserId: anonymousUserId, // Same ID for linking
        authProvider: 'email',
        preservedUserId: true, // ID was preserved during linking
      );

      // CRITICAL: Invalidate userIdProvider to force re-read with updated authUserId
      // Without this, the provider remains cached with old data
      ref.invalidate(userIdProvider);
      _logger.info(
        'Invalidated userIdProvider after auth update',
        context: 'EMAIL_AUTH',
      );

      // Track successful linking in analytics
      await _analytics.track(
        'email_account_linked',
        properties: {
          'user_id': response.user!.id,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      _logger.info('Email account linking complete', context: 'EMAIL_AUTH');

      // Note: Email confirmation is optional for faster onboarding
      // Users can still use the app immediately without confirming email
      if (response.user!.emailConfirmedAt == null) {
        _logger.info(
          'Email confirmation pending (optional)',
          context: 'EMAIL_AUTH',
        );
      }
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      final error = state.error;
      _logger.error(
        'Email account linking failed',
        context: 'EMAIL_AUTH',
        error: error,
      );

      // Track failure in analytics
      await _analytics.track(
        'email_account_linking_failed',
        properties: {'error': error.toString()},
      );

      // Check for "already registered" error - throw specific exception for UI to handle
      if (error is AuthApiException) {
        if (error.message.contains('already registered') ||
            error.message.contains('already been registered') ||
            error.message.contains('User already registered')) {
          throw AccountAlreadyExistsException(
            'This email is already registered',
            email: email,
          );
        } else if (error.message.contains('invalid')) {
          throw Exception('Please enter a valid email address.');
        } else if (error.message.contains('weak password')) {
          throw Exception(
            'Please use a stronger password (at least 8 characters).',
          );
        }
      }

      throw Exception('Account creation failed. Please try again.');
    }
  }

  /// Sign up with email/password (creates NEW user)
  /// Used when no Supabase session exists (during onboarding)
  /// This creates a brand new Supabase auth user with email/password credentials
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      _logger.info(
        'Starting email signup (new user)',
        context: 'EMAIL_AUTH',
        data: {'email_length': email.length},
      );

      // Validate inputs
      final emailValidation = validateEmail(email);
      if (emailValidation != null) {
        throw Exception(emailValidation);
      }

      final passwordValidation = validatePassword(password);
      if (passwordValidation != null) {
        throw Exception(passwordValidation);
      }

      // Create NEW Supabase auth user with email/password
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to create account - no user returned');
      }

      final newUserId = response.user!.id;

      _logger.info(
        'Email signup successful',
        context: 'EMAIL_AUTH',
        data: {
          'user_id': newUserId,
          'email': response.user!.email,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      // NOTE: Do NOT call completeAuthentication() or clear onboarding_temp_user_id here.
      // During onboarding, activities/integrations synced from Final Surge / Training Peaks
      // are stored locally under a temp UUID and were never uploaded to Supabase.
      // completeAuthentication() checks Supabase for data (finds none) and skips migration.
      // Instead, onboardingController.saveAllOnboardingData() handles migration via
      // _migrateOnboardingDataToNewUser() which correctly migrates LOCAL database data
      // and clears the temp user ID afterward.

      // CRITICAL: Invalidate userIdProvider to force re-read with new user
      ref.invalidate(userIdProvider);
      _logger.info(
        'Invalidated userIdProvider after signup',
        context: 'EMAIL_AUTH',
      );

      // Track successful signup in analytics
      await _analytics.track(
        'email_account_created',
        properties: {
          'user_id': newUserId,
          'email_confirmed': response.user!.emailConfirmedAt != null,
        },
      );

      _logger.info('Email signup complete', context: 'EMAIL_AUTH');
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      final error = state.error;
      _logger.error('Email signup failed', context: 'EMAIL_AUTH', error: error);

      // Track failure in analytics
      await _analytics.track(
        'email_signup_failed',
        properties: {'error': error.toString()},
      );

      // Check for "already registered" error - throw specific exception for UI to handle
      if (error is AuthApiException) {
        if (error.message.contains('already registered') ||
            error.message.contains('already been registered') ||
            error.message.contains('User already registered')) {
          throw AccountAlreadyExistsException(
            'This email is already registered',
            email: email,
          );
        } else if (error.message.contains('invalid')) {
          throw Exception('Please enter a valid email address.');
        } else if (error.message.contains('weak password')) {
          throw Exception(
            'Please use a stronger password (at least 8 characters).',
          );
        }
      }

      throw Exception('Account creation failed. Please try again.');
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
      _logger.info(
        'Starting email sign in',
        context: 'EMAIL_AUTH',
        data: {'email_length': email.length},
      );

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
      var previousUserId = _supabase.auth.currentUser?.id;
      var wasAnonymous = _supabase.auth.currentUser?.isAnonymous ?? false;

      // Also check for temp onboarding user ID (used when no Supabase session exists)
      // This handles the case where user synced with TP/FS during onboarding then signs in
      final prefs = ref.read(sharedPreferencesProvider);
      final tempUserId = prefs.getString('onboarding_temp_user_id');
      if (previousUserId == null && tempUserId != null) {
        previousUserId = tempUserId;
        wasAnonymous = true;
      }

      _logger.info(
        'Capturing user state before sign-in',
        context: 'EMAIL_AUTH',
        data: {
          'previous_user_id': previousUserId,
          'was_anonymous': wasAnonymous,
          'had_temp_user_id': tempUserId != null,
        },
      );

      // Sign in with Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw Exception('Sign in failed - no session returned');
      }

      final newUserId = response.user!.id;

      _logger.info(
        'Email sign in successful',
        context: 'EMAIL_AUTH',
        data: {'user_id': newUserId, 'email': response.user!.email},
      );

      // Complete authentication (unified flow for all providers)
      final authMigrationService = await ref.read(
        authMigrationServiceProvider.future,
      );
      final dataMigrated = await authMigrationService.completeAuthentication(
        previousUserId: previousUserId,
        wasAnonymous: wasAnonymous,
        newUserId: newUserId,
        authProvider: 'email',
        preservedUserId: false, // ID changed during sign-in
      );

      // Clear temp user ID after successful migration
      if (tempUserId != null) {
        await prefs.remove('onboarding_temp_user_id');
        _logger.info(
          'Cleared onboarding temp user ID after sign-in migration',
          context: 'EMAIL_AUTH',
        );
      }

      // CRITICAL: Invalidate userIdProvider to force re-read after auth change
      ref.invalidate(userIdProvider);
      _logger.info(
        'Invalidated userIdProvider after sign-in',
        context: 'EMAIL_AUTH',
      );

      _logger.info(
        'Sign-in completion handled',
        context: 'EMAIL_AUTH',
        data: {'data_migrated': dataMigrated},
      );

      // Track successful sign in
      await _analytics.track(
        'email_sign_in_success',
        properties: {'user_id': newUserId, 'migrated_data': dataMigrated},
      );

      // Trigger sync after sign-in to pull user data from Supabase
      // This is essential for new device logins where local DB is empty
      _logger.info(
        'Triggering post-sign-in sync',
        context: 'EMAIL_AUTH',
        data: {'user_id': newUserId},
      );

      try {
        // CRITICAL: Clear sync timestamp to force full sync (not incremental)
        // Otherwise, if user logs out and back in on same device, we might send
        // an old timestamp and get no data back (because local DB was cleared)
        final prefs = ref.read(sharedPreferencesProvider);
        await prefs.remove('last_sync_timestamp_$newUserId');

        // Sync all data including coach status (handled by edge function)
        await ref
            .read(syncCoordinatorProvider.notifier)
            .sync(userId: newUserId, trigger: SyncTrigger.oauthSignIn);
        _logger.info('Post-sign-in sync completed', context: 'EMAIL_AUTH');
      } catch (e) {
        _logger.error(
          'Post-sign-in sync failed',
          context: 'EMAIL_AUTH',
          error: e,
        );
        // Don't rethrow - sign-in was successful, user can pull-to-refresh
      }
    });

    // Re-throw errors for UI to handle
    if (state.hasError) {
      _logger.error(
        'Email sign in failed',
        context: 'EMAIL_AUTH',
        error: state.error,
      );
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
