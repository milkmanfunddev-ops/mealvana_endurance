import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database_provider.dart';

part 'device_id_provider.g.dart';

/// Provides the device ID for the current user from the user_profiles table.
///
/// This is used throughout the app for user identification since we use
/// device-based identity rather than an authentication system.
@riverpod
Future<String> deviceId(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);

  // Get the current user profile from the database
  final userProfile = await database.getCurrentUserProfile();

  if (userProfile == null) {
    throw Exception('No user profile found. User must complete onboarding first.');
  }

  // Note: UserProfile.id is the device_id (see UserProfile.fromJson and toJson)
  return userProfile.id;
}
