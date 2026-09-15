import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/app_external_deps.dart';

part 'is_admin_provider.g.dart';

/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.
@Riverpod(keepAlive: true)
Future<bool> isAdmin(Ref ref) async {
  final deps = ref.watch(appExternalDepsProvider);
  final authUserId = deps.supabaseClient.auth.currentUser?.id;
  if (authUserId == null) return false;
  try {
    final row = await deps.supabaseClient
        .from('users')
        .select('is_admin')
        .eq('id', authUserId)
        .maybeSingle();
    return adminFlagFromUsersRow(row);
  } catch (e) {
    deps.logger.warning(
      'is_admin read failed; treating as not admin',
      context: 'IS_ADMIN',
      error: e,
    );
    return false;
  }
}

/// `users.is_admin` as PostgREST returns it: `true`, `false`, `null` (an
/// older row or a schema without the column), or no row at all.
bool adminFlagFromUsersRow(Map<String, dynamic>? row) =>
    row?['is_admin'] == true;
