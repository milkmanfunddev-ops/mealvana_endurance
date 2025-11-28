// import 'package:riverpod_annotation/riverpod_annotation.dart';
// import '../database/database_provider.dart';

// part 'device_id_provider.g.dart';

// /// Provides the device ID (auth/user UUID) for the current user.
// ///
// /// This provider must stay alive for the entire session so background services
// /// (sync, repositories, etc.) can await it safely without hitting autoDispose
// /// race conditions.
// @Riverpod(keepAlive: true)
// Future<String> deviceId(Ref ref) async {
//   final database = ref.watch(appDatabaseProvider);

//   // Get the current user profile from the database
//   final userProfile = await database.getCurrentUserProfile();

//   if (userProfile == null) {
//     throw Exception('No user proafile found. User must complete onboarding first.');
//   }

//   // Note: UserProfile.id is the device_id (see UserProfile.fromJson and toJson)
//   return userProfile.id;
// }
