import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/database_provider.dart';
import '../services/app_external_deps.dart';
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
  final authUserFromStream = authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
  // Read from Supabase session directly to avoid waiting on stream timing.
  final currentAuthUserId = ref
      .read(appExternalDepsProvider)
      .supabaseClient
      .auth
      .currentUser
      ?.id;
  final supabaseUserId = currentAuthUserId ?? authUserFromStream?.id;

  // If Supabase already has an authenticated user, prefer that ID immediately.
  if (supabaseUserId != null) {
    // CRITICAL FIX: Look up user by authUserId, not by id
    // During guest flow, the user's id (primary key) may differ from authUserId
    // Example: id=23a9302f..., authUserId=4ecdb31c...
    final existingProfile = await database.userDao.getUserProfileByAuthUserId(
      supabaseUserId,
    );
    if (existingProfile != null) {
      return existingProfile.id;
    }

    // No matching profile cached yet – hydrate from Supabase.
    final userRepository = await ref.read(userRepositoryProvider.future);
    final remoteProfile = await userRepository.fetchAndSaveRemoteProfile(
      supabaseUserId,
    );
    if (remoteProfile != null) {
      await userRepository.fetchAndCacheRemoteFoodPreferences(supabaseUserId);
      return remoteProfile.id;
    }

    // Last resort: return the Supabase auth ID so the app can proceed.
    return supabaseUserId;
  }

  // Supabase auth stream hasn't yielded a user yet (app startup / offline mode)
  // Without an authenticated user, there's no current profile.
  // Note: getCurrentUserProfile(currentAuthUserId: null) returns null,
  // which is correct - no auth session means no current user.
  final cachedProfile = await database.userDao.getCurrentUserProfile(
    currentAuthUserId: null,
  );
  if (cachedProfile != null) {
    return cachedProfile.id;
  }

  throw Exception(
    'No user profile found. User must complete onboarding first.',
  );
}
