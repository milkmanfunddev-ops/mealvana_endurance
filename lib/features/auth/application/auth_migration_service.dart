import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../data/user_repository.dart';
import '../domain/user_preferences.dart';

part 'auth_migration_service.g.dart';

/// Service for handling OAuth migration logic from anonymous profiles
/// Extracted from UserRepository to follow FOA pattern
///
/// NOTE: This is a simple class with a function provider (NOT an AsyncNotifier).
/// AsyncNotifier providers get disposed during async gaps, which breaks auth flows
/// that call completeAuthentication() after Supabase auth calls.
class AuthMigrationService {
  AuthMigrationService({
    required this.userRepository,
    required this.database,
    required this.supabase,
    required this.sentry,
  });

  final UserRepository userRepository;
  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryReporter sentry;

  /// Migrate all data from anonymous user to OAuth user when signing into existing account
  /// This is called when account linking fails (account already exists) and user chooses to sign in
  /// The anonymous user's data is merged into the existing OAuth user's account
  Future<void> migrateAnonymousUserData({
    required String fromAnonymousUserId,
    required String toOAuthUserId,
    String authProvider = 'google',
  }) async {
    try {
      // Get the anonymous user's profile to preserve their data
      final anonymousProfile = await userRepository.getUserProfileById(
        fromAnonymousUserId,
      );
      if (anonymousProfile == null) {
        sentry.addBreadcrumb(
          message: 'No anonymous profile found to migrate',
          category: 'auth',
          data: {'from_user_id': fromAnonymousUserId},
        );
        return;
      }

      // CRITICAL FIX: Check if OAuth user has existing data on server
      // If they do, we should KEEP their existing data, not replace it with anonymous onboarding data
      // We check for ACTUAL DATA (activities, events), not just user profile existence
      // because the auth trigger might have created an empty profile.
      bool oauthUserHasData = false;
      try {
        oauthUserHasData = await userRepository.checkUserHasData(toOAuthUserId);
      } catch (e) {
        // FAIL SAFE: Assume data exists to prevent data loss on network error
        sentry.addBreadcrumb(
          message:
              'Error checking OAuth user data - assuming exists to prevent data loss',
          category: 'auth',
          data: {'error': e.toString()},
        );
        oauthUserHasData = true;
      }

      if (oauthUserHasData) {
        // SCENARIO A: EXISTING OAuth user signing in on new device
        // - OAuth user has historical data on server (e.g., 50 activities from last year)
        // - Anonymous user has test/onboarding data from new device (e.g., 1 test activity)
        // - CORRECT BEHAVIOR: Keep OAuth data, discard anonymous data
        sentry.addBreadcrumb(
          message:
              'OAuth user exists on server - preserving existing data, discarding anonymous data',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );

        // Delete anonymous user's local data (will be replaced by server data on next sync)
        await _clearAnonymousUserLocalData(fromAnonymousUserId);

        // Update local user profile to OAuth user
        final oauthProfile = anonymousProfile.copyWith(
          id: toOAuthUserId,
          authUserId: toOAuthUserId,
          authProvider: authProvider,
          isAnonymous: false,
          updatedAt: DateTime.now(),
        );
        await userRepository.saveUserProfile(oauthProfile);

        sentry.addBreadcrumb(
          message:
              'Cleared anonymous data - OAuth user data will sync from server',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );
      } else {
        // SCENARIO B: NEW OAuth account (never used the app before)
        // - OAuth user has NO data on server
        // - Anonymous user has fresh onboarding data from this device
        // - CORRECT BEHAVIOR: Keep anonymous data, migrate it to OAuth user
        sentry.addBreadcrumb(
          message: 'New OAuth account - migrating anonymous user data',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );

        // STEP 1: Migrate all user-scoped data in Supabase (child tables first)
        // This must happen BEFORE deleting the anonymous user due to foreign key constraints
        await _migrateSupabaseData(
          fromUserId: fromAnonymousUserId,
          toUserId: toOAuthUserId,
        );

        // STEP 2: Delete anonymous user from Supabase BEFORE creating OAuth user
        // This frees up the device_id for the OAuth user
        await _deleteAnonymousUserFromSupabase(fromAnonymousUserId);

        // STEP 3: Create or update OAuth user in Supabase public.users
        // UPSERT handles both new and existing users automatically
        await _upsertOAuthUserFromAnonymousProfile(
          oauthUserId: toOAuthUserId,
          anonymousProfile: anonymousProfile,
          authProvider: authProvider,
        );

        // STEP 4: Update local database with OAuth user ID
        await _migrateLocalData(
          fromUserId: fromAnonymousUserId,
          toUserId: toOAuthUserId,
          anonymousProfile: anonymousProfile,
          authProvider: authProvider,
        );

        sentry.addBreadcrumb(
          message:
              'Successfully migrated anonymous user data to new OAuth user',
          category: 'auth',
          data: {
            'from_user_id': fromAnonymousUserId,
            'to_user_id': toOAuthUserId,
          },
        );
      }
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'migrateAnonymousUserData',
        table: 'multiple',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete anonymous user from Supabase public.users table
  /// This must be called AFTER migrating child table data to free up the device_id
  Future<void> _deleteAnonymousUserFromSupabase(String anonymousUserId) async {
    try {
      await supabase.from('users').delete().eq('id', anonymousUserId);

      sentry.addBreadcrumb(
        message: 'Deleted anonymous user from Supabase',
        category: 'auth',
        data: {'anonymous_user_id': anonymousUserId},
      );
    } catch (e, stackTrace) {
      // Log but don't throw - user may not exist in Supabase
      sentry.addBreadcrumb(
        message:
            'Failed to delete anonymous user from Supabase (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:delete',
        method: 'DELETE',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update existing OAuth user in Supabase with anonymous user's profile data
  /// Called when OAuth user already exists but we want to update their device_id and merge profile
  /// UNIFIED: Create or update OAuth user in Supabase using anonymous user's profile data
  /// Uses UPSERT to handle both new and existing OAuth users
  Future<void> _upsertOAuthUserFromAnonymousProfile({
    required String oauthUserId,
    required UserProfile anonymousProfile,
    required String authProvider,
  }) async {
    try {
      // UPSERT user record with OAuth user ID and anonymous user's data
      // This works whether the OAuth user exists or not
      await supabase.from('users').upsert({
        'id': oauthUserId,
        'device_id': anonymousProfile.deviceId,
        'auth_user_id': oauthUserId,
        'auth_provider': authProvider,
        'is_anonymous': false,
        'gender': anonymousProfile.gender.name,
        'birthday': anonymousProfile.birthday.toIso8601String().split('T')[0],
        'height_feet': anonymousProfile.heightFeet,
        'height_inches': anonymousProfile.heightInches,
        'weight_pounds': anonymousProfile.weightPounds,
        'runs_with_water_bottle': anonymousProfile.runsWithWaterBottle,
        'gut_training_level': anonymousProfile.gutTraining.name,
        'onboarding_completed': anonymousProfile.onboardingCompleted,
        'app_version': anonymousProfile.appVersion,
        'gi_sensitivity': anonymousProfile.giSensitivity,
        'cycling_ftp_watts': anonymousProfile.ftpWatts,
        'typical_bike_bottles': anonymousProfile.typicalBikeBottles,
        'has_aero_bottle': anonymousProfile.hasAeroBottle,
        'has_bento_box': anonymousProfile.hasBentoBox,
        'swimming_css_seconds_per_100m': anonymousProfile.cssPacePer100mSeconds,
        'typical_wetsuit': anonymousProfile.typicalWetsuit,
        'typical_swim_cap_type': anonymousProfile.typicalSwimCapType,
        'first_name': anonymousProfile.firstName,
        'last_name': anonymousProfile.lastName,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      sentry.addBreadcrumb(
        message: 'Upserted OAuth user in Supabase with anonymous profile data',
        category: 'auth',
        data: {'oauth_user_id': oauthUserId, 'auth_provider': authProvider},
      );
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Migrate data in Supabase from anonymous user to OAuth user
  /// Strategy: DELETE OAuth user's existing data first, then UPDATE anonymous user's data
  /// This prevents UNIQUE constraint violations when OAuth user already has data
  Future<void> _migrateSupabaseData({
    required String fromUserId,
    required String toUserId,
  }) async {
    // ============ EVENTS ============
    // Events have UNIQUE constraint on (user_id, event_date, event_name) - delete OAuth's first
    try {
      await supabase.from('events').delete().eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user events (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('events')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate events (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ ACTIVITIES ============
    // Activities have UNIQUE constraint on (user_id, scheduled_date) - delete OAuth's first
    try {
      await supabase.from('activities').delete().eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user activities (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('activities')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate activities (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ FOOD PREFERENCES ============
    // Food preferences have UNIQUE constraint on (user_id, food_name) - delete OAuth's first
    try {
      await supabase.from('food_preferences').delete().eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user food_preferences (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('food_preferences')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate food_preferences (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ USER FOODS ============
    // User foods have UNIQUE constraint on (user_id, food_name) - delete OAuth's first
    try {
      await supabase.from('user_foods').delete().eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user user_foods (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('user_foods')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate user_foods (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ CARB LOADING PLANS ============
    // Delete OAuth user's carb loading plans first to prevent conflicts
    // Note: carb_loading_days is a CHILD table with ON DELETE CASCADE in Supabase,
    // so deleting plans will automatically delete associated days
    try {
      await supabase
          .from('carb_loading_plans')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message:
            'Failed to delete OAuth user carb_loading_plans (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    // Migrate anonymous user's carb loading plans to OAuth user
    // Note: carb_loading_days does NOT have user_id column - it inherits
    // user ownership through carb_loading_plan_id foreign key
    try {
      await supabase
          .from('carb_loading_plans')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate carb_loading_plans (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ FEEDBACK ============
    // Note: feedback table uses device_id, NOT user_id
    // Feedback stays with the device, not migrated with user account
    // No migration needed here
  }

  /// Migrate local Drift database data
  Future<void> _migrateLocalData({
    required String fromUserId,
    required String toUserId,
    required UserProfile anonymousProfile,
    required String authProvider,
  }) async {
    // STEP 1: Update user_id in all local child tables (activities, events, etc.)
    // This must happen BEFORE deleting the anonymous user profile
    await database.diagnosticDao.migrateUserData(fromUserId, toUserId);

    // Note: migrateUserData already deletes the anonymous user profile from the local DB
    // Now we just need to create/update the OAuth user profile

    // STEP 2: Create new profile with OAuth user ID
    final migratedProfile = anonymousProfile.copyWith(
      id: toUserId,
      authUserId: toUserId,
      authProvider: authProvider,
      isAnonymous: false,
      updatedAt: DateTime.now(),
    );

    // STEP 3: Save the migrated OAuth user profile
    await userRepository.saveUserProfile(migratedProfile);
  }

  /// Clear anonymous user's local data when OAuth user has existing data on server
  /// This prevents data loss - OAuth user's server data will be downloaded on next sync
  Future<void> _clearAnonymousUserLocalData(String anonymousUserId) async {
    await database.transaction(() async {
      // Delete anonymous user's activities
      await database.customStatement(
        'DELETE FROM activities WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's events
      await database.customStatement('DELETE FROM events WHERE user_id = ?', [
        anonymousUserId,
      ]);

      // Delete anonymous user's food preferences
      await database.customStatement(
        'DELETE FROM food_preferences_table WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's custom foods
      await database.customStatement(
        'DELETE FROM user_foods WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's carb loading data (manual cascade - Drift doesn't have FK cascades)
      // Delete child tables first (carb_loading_day_meals -> carb_loading_days -> carb_loading_plans)

      // Step 1: Delete carb_loading_day_meals via carb_loading_days via carb_loading_plans
      await database.customStatement(
        '''
        DELETE FROM carb_loading_day_meals
        WHERE carb_loading_day_id IN (
          SELECT id FROM carb_loading_days
          WHERE carb_loading_plan_id IN (
            SELECT id FROM carb_loading_plans WHERE user_id = ?
          )
        )
      ''',
        [anonymousUserId],
      );

      // Step 2: Delete carb_loading_days via carb_loading_plans
      await database.customStatement(
        '''
        DELETE FROM carb_loading_days
        WHERE carb_loading_plan_id IN (
          SELECT id FROM carb_loading_plans WHERE user_id = ?
        )
      ''',
        [anonymousUserId],
      );

      // Step 3: Delete carb_loading_plans
      await database.customStatement(
        'DELETE FROM carb_loading_plans WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's carb loading user foods
      await database.customStatement(
        'DELETE FROM carb_loading_user_foods WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user profile
      await database.customStatement('DELETE FROM users WHERE id = ?', [
        anonymousUserId,
      ]);
    });

    sentry.addBreadcrumb(
      message: 'Cleared anonymous user local data',
      category: 'auth',
      data: {'anonymous_user_id': anonymousUserId},
    );
  }

  /// UNIFIED: Complete authentication for ANY provider (Apple, Google, Email)
  /// This is the single entry point for all post-authentication logic.
  ///
  /// Handles three scenarios:
  /// 1. Account Linking (preservedUserId=true): User ID stays same, just updates provider
  /// 2. Sign-In with Migration (ID changed + wasAnonymous): Migrates data from anonymous user
  /// 3. Fresh Login (no previous user): Fetches/creates profile
  ///
  /// @param previousUserId - User ID before authentication (null if fresh install)
  /// @param wasAnonymous - Whether previous user was anonymous
  /// @param newUserId - User ID after authentication
  /// @param authProvider - 'apple', 'google', or 'email'
  /// @param preservedUserId - true for account linking, false for sign-in
  ///
  /// Returns true if data was migrated, false otherwise
  Future<bool> completeAuthentication({
    required String? previousUserId,
    required bool wasAnonymous,
    required String newUserId,
    required String authProvider,
    bool preservedUserId = false,
  }) async {
    try {
      bool dataMigrated = false;

      // Determine if we need to migrate data
      final needsMigration =
          previousUserId != null &&
          previousUserId != newUserId &&
          wasAnonymous &&
          !preservedUserId;

      if (needsMigration) {
        // SCENARIO 1: Sign-In with Migration (user ID changed)
        sentry.addBreadcrumb(
          message: 'Auth complete - migrating anonymous user data',
          category: 'auth',
          data: {
            'scenario': 'migration',
            'from_user_id': previousUserId,
            'to_user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        final hasDataToMigrate = await userRepository.checkUserHasData(
          previousUserId,
        );
        if (hasDataToMigrate) {
          await migrateAnonymousUserData(
            fromAnonymousUserId: previousUserId,
            toOAuthUserId: newUserId,
            authProvider: authProvider,
          );
          dataMigrated = true;
        } else {
          await _handleFreshLogin(newUserId, authProvider);
        }
      } else if (preservedUserId) {
        // SCENARIO 2: Account Linking (user ID preserved)
        sentry.addBreadcrumb(
          message: 'Auth complete - account linked',
          category: 'auth',
          data: {
            'scenario': 'linking',
            'user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        // Avoid updateAuthProvider() here because it calls getCurrentUser(),
        // which can race immediately after Supabase session switches.
        await _handleFreshLogin(newUserId, authProvider);
      } else {
        // SCENARIO 3: Fresh Login (no migration needed)
        sentry.addBreadcrumb(
          message: 'Auth complete - fresh login',
          category: 'auth',
          data: {
            'scenario': 'fresh_login',
            'user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        await _handleFreshLogin(newUserId, authProvider);
      }

      return dataMigrated;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'completeAuthentication',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// DEPRECATED: Use completeAuthentication() instead
  /// Handle post-sign-in completion for all auth methods (Google, Apple, Email)
  /// This consolidates the common logic that must run after any sign-in:
  /// 1. Migrate data if coming from anonymous user with data
  /// 2. Update auth provider and isAnonymous flag
  ///
  /// Note: Sync should be triggered by the caller after this method completes
  /// since UserRepository doesn't have access to Riverpod ref.
  ///
  /// Returns true if data was migrated, false if just auth provider was updated
  Future<bool> handleSignInCompletion({
    required String? previousUserId,
    required bool wasAnonymous,
    required String newUserId,
    required String authProvider,
  }) async {
    try {
      bool dataMigrated = false;

      // Check if we need to migrate data from anonymous user
      final needsMigration =
          previousUserId != null && previousUserId != newUserId && wasAnonymous;

      if (needsMigration) {
        // Check if the anonymous user actually has data worth migrating
        final hasDataToMigrate = await userRepository.checkUserHasData(
          previousUserId,
        );

        if (hasDataToMigrate) {
          sentry.addBreadcrumb(
            message: 'Migrating anonymous user data during sign-in',
            category: 'auth',
            data: {
              'from_user_id': previousUserId,
              'to_user_id': newUserId,
              'auth_provider': authProvider,
            },
          );

          await migrateAnonymousUserData(
            fromAnonymousUserId: previousUserId,
            toOAuthUserId: newUserId,
            authProvider: authProvider,
          );
          dataMigrated = true;
        } else {
          sentry.addBreadcrumb(
            message: 'Skipping migration - anonymous user has no data',
            category: 'auth',
            data: {
              'anonymous_user_id': previousUserId,
              'new_user_id': newUserId,
            },
          );
          // Try to update auth provider, but fallback if user is missing
          // This handles race conditions where AppStartupService might have cleared the anonymous user
          try {
            await userRepository.updateAuthProvider(
              authProvider: authProvider,
              isAnonymous: false,
            );
          } catch (e) {
            if (e.toString().contains('No current user found')) {
              sentry.addBreadcrumb(
                message:
                    'User missing during auth update - treating as fresh login',
                category: 'auth',
              );
              await _handleFreshLogin(newUserId, authProvider);
            } else {
              rethrow;
            }
          }
        }
      } else {
        // No migration needed - fetch/create user profile then update auth provider
        // This handles:
        // - User signing back into their existing account
        // - User was not anonymous before sign-in
        sentry.addBreadcrumb(
          message: 'Updating auth provider (no migration needed)',
          category: 'auth',
          data: {
            'user_id': newUserId,
            'auth_provider': authProvider,
            'previous_user_id': previousUserId,
            'was_anonymous': wasAnonymous,
          },
        );

        await _handleFreshLogin(newUserId, authProvider);
      }

      return dataMigrated;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'handleSignInCompletion',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Handle fresh login (fetch remote profile or create new in Supabase)
  Future<void> _handleFreshLogin(String userId, String authProvider) async {
    sentry.addBreadcrumb(
      message: 'Starting fresh login flow',
      category: 'auth',
      data: {'user_id': userId, 'auth_provider': authProvider},
    );

    // Fetch user profile from Supabase (for existing accounts)
    final remoteProfile = await userRepository.fetchAndSaveRemoteProfile(
      userId,
    );

    if (remoteProfile != null) {
      // User exists in Supabase - update profile directly (no second lookup)
      // This fixes the "No current user found" error by avoiding getCurrentUser() race condition
      sentry.addBreadcrumb(
        message: 'Fresh login - profile found in Supabase, updating directly',
        category: 'auth',
        data: {
          'user_id': userId,
          'remote_auth_user_id': remoteProfile.authUserId,
          'onboarding_completed': remoteProfile.onboardingCompleted,
          'auth_provider': authProvider,
        },
      );

      // Directly update the fetched profile with current auth session values
      // This avoids calling updateAuthProvider() which does a getCurrentUser() lookup
      // that can fail if authUserId doesn't match the new session yet
      final sessionEmail = supabase.auth.currentUser?.email;
      final updatedProfile = remoteProfile.copyWith(
        authUserId:
            userId, // Ensure authUserId matches current Supabase session
        authProvider: authProvider,
        isAnonymous: false,
        // Carry the address the user just proved onto the profile row.
        email: (sessionEmail != null && sessionEmail.isNotEmpty)
            ? sessionEmail
            : remoteProfile.email,
        updatedAt: DateTime.now(),
      );

      // updateUserProfile (NOT saveUserProfile) because this must reach
      // Supabase: a local-only save left `users.is_anonymous` true on the
      // server for every upgraded-in-place account, so the row still looked
      // anonymous despite carrying a real identity. updateUserProfile
      // write-throughs and, if the write fails, marks the row needs_upload so
      // background sync retries — no silently-dropped flip.
      await userRepository.updateUserProfile(updatedProfile);

      sentry.addBreadcrumb(
        message: 'Fresh login - profile updated successfully',
        category: 'auth',
        data: {
          'user_id': userId,
          'auth_user_id': updatedProfile.authUserId,
          'is_anonymous': updatedProfile.isAnonymous,
        },
      );
    } else {
      // CRITICAL: Profile not found in Supabase - create it NOW
      // This happens when user signs in for first time or after local DB wipe
      sentry.addBreadcrumb(
        message: 'Fresh login - profile NOT found in Supabase, creating it',
        category: 'auth',
        data: {'user_id': userId, 'auth_provider': authProvider},
      );

      final now = DateTime.now();
      final newProfile = UserProfile(
        id: userId,
        deviceId: '', // Will be set by app startup service
        authUserId: userId,
        authProvider: authProvider,
        isAnonymous: false,
        gender: Gender.male,
        birthday: DateTime(1990, 1, 1),
        heightFeet: 5,
        heightInches: 10,
        weightPounds: 150,
        runsWithWaterBottle: false,
        gutTraining: GutTraining.moderate,
        onboardingCompleted: false,
        appVersion: '1.0.0',
        createdAt: now,
        updatedAt: now,
      );

      await userRepository.saveUserProfile(newProfile);
      await userRepository.createUserInSupabase(userId, newProfile);

      sentry.addBreadcrumb(
        message: 'Fresh login - new profile created successfully',
        category: 'auth',
        data: {
          'user_id': userId,
          'auth_user_id': newProfile.authUserId,
          'is_anonymous': newProfile.isAnonymous,
        },
      );
    }
  }
}

/// Riverpod provider for AuthMigrationService
/// Uses a simple async function provider (NOT AsyncNotifier) to prevent disposal during auth flows
@riverpod
Future<AuthMigrationService> authMigrationService(Ref ref) async {
  final userRepository = await ref.watch(userRepositoryProvider.future);
  final database = ref.watch(appDatabaseProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  final sentry = ref.watch(sentryReporterProvider);

  return AuthMigrationService(
    userRepository: userRepository,
    database: database,
    supabase: supabase,
    sentry: sentry,
  );
}
