import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_profiles.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart' as run_params;
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart' as domain;
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../features/onboarding/domain/dietary_preference.dart';
import '../../../features/onboarding/domain/allergy.dart';
import '../../../features/daily_macros/domain/enums.dart';

part 'user_dao.g.dart';

/// Data Access Object for user profiles and authentication-related data.
///
/// This DAO handles:
/// - CRUD operations for user profiles
/// - User authentication state queries
/// - Device-based user lookup
@DriftAccessor(tables: [UserProfilesTable])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  /// Get the current user profile for the authenticated session.
  ///
  /// [currentAuthUserId] - The current Supabase auth user ID. Pass null if no auth session.
  ///
  /// Returns the profile matching the auth user ID, or null if:
  /// - No auth user ID provided (user not authenticated)
  /// - No profile found matching the auth user ID
  ///
  /// This ensures that after logout, getCurrentUserProfile() returns null
  /// even if old profile data exists in the database from a previous user.
  Future<domain.UserProfile?> getCurrentUserProfile({
    String? currentAuthUserId,
  }) async {
    // If no auth user ID provided, there's no current user
    // This happens after logout when no Supabase session exists
    if (currentAuthUserId == null) {
      return null;
    }

    // Find profile matching this auth user
    return getUserProfileByAuthUserId(currentAuthUserId);
  }

  /// Look up a user profile by Supabase auth user ID.
  Future<domain.UserProfile?> getUserProfileByAuthUserId(String authUserId) async {
    final result = await (select(userProfilesTable)
          ..where((u) => u.authUserId.equals(authUserId))
          ..limit(1))
        .getSingleOrNull();

    if (result == null) {
      return null;
    }

    return _convertToDomainUserProfile(result);
  }

  /// Look up a user profile by its primary key/ID.
  Future<domain.UserProfile?> getUserProfileById(String userId) async {
    final result = await (select(userProfilesTable)
          ..where((u) => u.id.equals(userId))
          ..limit(1))
        .getSingleOrNull();

    if (result == null) {
      return null;
    }

    return _convertToDomainUserProfile(result);
  }

  /// Save a user profile
  ///
  /// [needsUpload] - If true, marks profile for background upload to Supabase
  ///
  /// IMPORTANT: This method handles the case where a different user exists
  /// with the same device_id. It deletes any existing user with the same
  /// device_id before inserting the new user.
  Future<void> saveUserProfile(
    domain.UserProfile profile, {
    bool needsUpload = false,
  }) async {
    // Delete any existing user with this device_id that has a DIFFERENT id
    // This handles the case where a new user is created on a device that already has a user
    await (delete(userProfilesTable)
          ..where((u) =>
              u.deviceId.equals(profile.deviceId) &
              u.id.equals(profile.id).not()))
        .go();

    await into(userProfilesTable).insertOnConflictUpdate(
      UserProfilesTableCompanion.insert(
        id: profile.id,
        deviceId: profile.deviceId,
        authUserId: Value(profile.authUserId),
        authProvider: Value(profile.authProvider),
        isAnonymous: Value(profile.isAnonymous),
        gender: Value(profile.gender.name),
        birthday: Value(profile.birthday),
        heightFeet: Value(profile.heightFeet),
        heightInches: Value(profile.heightInches),
        weightPounds: Value(profile.weightPounds),
        runsWithWaterBottle: Value(profile.runsWithWaterBottle),
        unitSystem: Value(profile.unitSystem.name),
        preferredDistanceUnit: Value(profile.preferredDistanceUnit.name),
        preferredPaceUnit: Value(profile.preferredPaceUnit.name),
        gutTrainingLevel: Value(profile.gutTraining.name),
        sweatRate: Value(profile.sweatRate.name),
        onboardingCompleted: Value(profile.onboardingCompleted),
        createdAt: Value(profile.createdAt),
        updatedAt: Value(profile.updatedAt),
        appVersion: Value(profile.appVersion),
        // Default pace/speed for workout estimation
        defaultRunningPaceMinPerMile: Value(profile.defaultRunningPaceMinPerMile),
        defaultCyclingSpeedMph: Value(profile.defaultCyclingSpeedMph),
        defaultSwimmingPacePer100Sec: Value(profile.defaultSwimmingPacePer100Sec),
        // Dietary preference and allergies
        // Convert DietaryPreference.none to null for database (constraint doesn't allow 'none')
        dietaryPreference: Value(
          profile.dietaryPreference == null ||
                  profile.dietaryPreference == DietaryPreference.none
              ? null
              : profile.dietaryPreference!.dbValue,
        ),
        allergies: Value(Allergy.toDbArray(profile.allergies)),
        // Optional name fields for coach mode athlete identification
        firstName: Value(profile.firstName),
        lastName: Value(profile.lastName),
        // Contact information
        email: Value(profile.email),
        // Nutrition target overrides (JSON string)
        nutritionTargetOverrides: Value(profile.nutritionTargetOverrides?.toJsonString()),
        // Daily macro calculation fields
        bodyFatPct: Value(profile.bodyFatPct),
        lifestyle: Value(profile.lifestyle.dbValue),
        typicalWeeklyHours: Value(profile.typicalWeeklyHours),
        carbCycleOptIn: Value(profile.carbCycleOptIn),
        trainingPhase: Value(profile.trainingPhase.dbValue),
        // Background sync tracking
        needsUpload: Value(needsUpload),
      ),
    );
  }

  /// Update user profile
  ///
  /// [needsUpload] - If true, marks profile for background upload to Supabase
  /// (defaults to true for onboarding updates)
  Future<void> updateUserProfile(
    domain.UserProfile profile, {
    bool needsUpload = true,
  }) async {
    await (update(userProfilesTable)..where((u) => u.id.equals(profile.id)))
        .write(
      UserProfilesTableCompanion(
        deviceId: Value(profile.deviceId),
        authUserId: Value(profile.authUserId),
        authProvider: Value(profile.authProvider),
        isAnonymous: Value(profile.isAnonymous),
        gender: Value(profile.gender.name),
        birthday: Value(profile.birthday),
        heightFeet: Value(profile.heightFeet),
        heightInches: Value(profile.heightInches),
        weightPounds: Value(profile.weightPounds),
        runsWithWaterBottle: Value(profile.runsWithWaterBottle),
        unitSystem: Value(profile.unitSystem.name),
        preferredDistanceUnit: Value(profile.preferredDistanceUnit.name),
        preferredPaceUnit: Value(profile.preferredPaceUnit.name),
        gutTrainingLevel: Value(profile.gutTraining.name),
        sweatRate: Value(profile.sweatRate.name),
        onboardingCompleted: Value(profile.onboardingCompleted),
        updatedAt: Value(DateTime.now()),
        appVersion: Value(profile.appVersion),
        // Default pace/speed for workout estimation
        defaultRunningPaceMinPerMile: Value(profile.defaultRunningPaceMinPerMile),
        defaultCyclingSpeedMph: Value(profile.defaultCyclingSpeedMph),
        defaultSwimmingPacePer100Sec: Value(profile.defaultSwimmingPacePer100Sec),
        // Dietary preference and allergies
        // Convert DietaryPreference.none to null for database (constraint doesn't allow 'none')
        dietaryPreference: Value(
          profile.dietaryPreference == null ||
                  profile.dietaryPreference == DietaryPreference.none
              ? null
              : profile.dietaryPreference!.dbValue,
        ),
        allergies: Value(Allergy.toDbArray(profile.allergies)),
        // Optional name fields for coach mode athlete identification
        firstName: Value(profile.firstName),
        lastName: Value(profile.lastName),
        // Contact information
        email: Value(profile.email),
        // Nutrition target overrides (JSON string)
        nutritionTargetOverrides: Value(profile.nutritionTargetOverrides?.toJsonString()),
        // Daily macro calculation fields
        bodyFatPct: Value(profile.bodyFatPct),
        lifestyle: Value(profile.lifestyle.dbValue),
        typicalWeeklyHours: Value(profile.typicalWeeklyHours),
        carbCycleOptIn: Value(profile.carbCycleOptIn),
        trainingPhase: Value(profile.trainingPhase.dbValue),
        // Background sync tracking
        needsUpload: Value(needsUpload),
      ),
    );
  }

  /// Delete user profile
  Future<bool> deleteUserProfile(String userId) async {
    final deletedRows =
        await (delete(userProfilesTable)..where((u) => u.id.equals(userId)))
            .go();
    return deletedRows > 0;
  }

  /// Check if any user data exists in the database
  Future<bool> hasUserData() async {
    final userCount = await (selectOnly(userProfilesTable)
          ..addColumns([userProfilesTable.id.count()]))
        .getSingle();
    return userCount.read(userProfilesTable.id.count())! > 0;
  }

  /// Update user notification preferences
  Future<void> updateUserNotificationPreferences({
    required String userId,
    required bool notificationsEnabled,
    required int defaultReminderDay,
    required int defaultReminderHour,
    required int defaultReminderMinute,
    required bool defaultReminderRecurring,
  }) async {
    await (update(userProfilesTable)..where((u) => u.id.equals(userId))).write(
      UserProfilesTableCompanion(
        notificationsEnabled: Value(notificationsEnabled),
        defaultReminderDay: Value(defaultReminderDay),
        defaultReminderHour: Value(defaultReminderHour),
        defaultReminderMinute: Value(defaultReminderMinute),
        defaultReminderRecurring: Value(defaultReminderRecurring),
      ),
    );
  }

  /// Check if swipe hint animation has been shown for current user
  /// NOTE: Swipe hint now uses SharedPreferences for global persistence
  /// This method is kept for backward compatibility with user profiles
  Future<bool> hasShownSwipeHint() async {
    final user = await getCurrentUserProfile();
    if (user != null) {
      return user.swipeHintShown;
    }
    return false; // Default to not shown if no user profile
  }

  /// Mark swipe hint animation as shown for current user
  /// NOTE: Swipe hint now uses SharedPreferences for global persistence
  /// This method is kept for backward compatibility with user profiles
  Future<void> markSwipeHintAsShown() async {
    final user = await getCurrentUserProfile();
    if (user != null) {
      await (update(userProfilesTable)..where((t) => t.id.equals(user.id)))
          .write(
        UserProfilesTableCompanion(
          swipeHintShown: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Convert database entry to domain model
  domain.UserProfile _convertToDomainUserProfile(UserProfileEntry dbUser) {
    return domain.UserProfile(
      id: dbUser.id,
      deviceId: dbUser.deviceId,
      authUserId: dbUser.authUserId,
      authProvider: dbUser.authProvider,
      isAnonymous: dbUser.isAnonymous,
      gender: domain.Gender.values.firstWhere(
        (g) => g.name == dbUser.gender,
        orElse: () => domain.Gender.other,
      ),
      birthday: dbUser.birthday ?? DateTime.now(),
      heightFeet: dbUser.heightFeet ?? 0,
      heightInches: dbUser.heightInches ?? 0,
      weightPounds: dbUser.weightPounds ?? 0.0,
      runsWithWaterBottle: dbUser.runsWithWaterBottle,
      unitSystem: run_params.UnitSystem.values.firstWhere(
        (u) => u.name == dbUser.unitSystem,
        orElse: () => run_params.UnitSystem.imperial,
      ),
      gutTraining: domain.GutTraining.values.firstWhere(
        (g) => g.name == dbUser.gutTrainingLevel,
        orElse: () => domain.GutTraining.moderate,
      ),
      sweatRate: domain.SweatRateCat.values.firstWhere(
        (s) => s.name == dbUser.sweatRate,
        orElse: () => domain.SweatRateCat.medium,
      ),
      onboardingCompleted: dbUser.onboardingCompleted,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      appVersion: dbUser.appVersion ?? '',
      swipeHintShown: dbUser.swipeHintShown,
      // Default pace/speed for workout estimation
      defaultRunningPaceMinPerMile: dbUser.defaultRunningPaceMinPerMile,
      defaultCyclingSpeedMph: dbUser.defaultCyclingSpeedMph,
      defaultSwimmingPacePer100Sec: dbUser.defaultSwimmingPacePer100Sec,
      // Dietary preference and allergies (onboarding revamp)
      // Convert null to DietaryPreference.none for UI
      dietaryPreference:
          DietaryPreference.fromDbValue(dbUser.dietaryPreference) ??
              DietaryPreference.none,
      allergies: Allergy.fromDbArray(dbUser.allergies),
      // Sharing preferences
      senderName: dbUser.senderName,
      // Optional name fields for coach mode athlete identification
      firstName: dbUser.firstName,
      lastName: dbUser.lastName,
      // Contact information
      email: dbUser.email,
      // Nutrition target overrides
      nutritionTargetOverrides: NutritionTargetOverrides.fromJsonString(
        dbUser.nutritionTargetOverrides,
      ),
      // Daily macro calculation fields
      bodyFatPct: dbUser.bodyFatPct,
      lifestyle: Lifestyle.fromDbValue(dbUser.lifestyle),
      typicalWeeklyHours: dbUser.typicalWeeklyHours,
      carbCycleOptIn: dbUser.carbCycleOptIn,
      trainingPhase: TrainingPhase.fromDbValue(dbUser.trainingPhase),
    );
  }
}
