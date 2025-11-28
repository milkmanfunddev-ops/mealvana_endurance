import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database_provider.dart';
import '../../features/auth/application/supabase_auth_service.dart'
    as supabase_auth;
import '../../features/auth/data/user_repository.dart';

part 'user_id_provider.g.dart';

/// Provides the user ID (auth UUID) for the current user.
///
/// This provider must stay alive for the entire session so background services
/// (sync, repositories, etc.) can await it safely without hitting autoDispose
/// race conditions.
@Riverpod(keepAlive: true)
Future<String> userId(Ref ref) async {
  final database = ref.watch(appDatabaseProvider);
  final authState = ref.watch(supabase_auth.currentUserProvider);
  final supabaseUser = authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );

  // If Supabase already has an authenticated user, prefer that ID immediately.
  if (supabaseUser != null) {
    // Ensure the local profile matches the authenticated Supabase user.
    final existingProfile =
        await database.getUserProfileById(supabaseUser.id);
    if (existingProfile != null) {
      return existingProfile.id;
    }

    // No matching profile cached yet – hydrate from Supabase.
    final userRepository = await ref.read(userRepositoryProvider.future);
    final remoteProfile =
        await userRepository.fetchAndSaveRemoteProfile(supabaseUser.id);
    if (remoteProfile != null) {
      await userRepository.fetchAndCacheRemoteFoodPreferences(supabaseUser.id);
      return remoteProfile.id;
    }

    // Last resort: return the Supabase auth ID so the app can proceed.
    return supabaseUser.id;
  }

  // Supabase auth stream hasn't yielded a user yet (app startup / offline mode)
  // Fallback to the latest cached user profile.
  final cachedProfile = await database.getCurrentUserProfile();
  if (cachedProfile != null) {
    return cachedProfile.id;
  }

  throw Exception('No user profile found. User must complete onboarding first.');
}
