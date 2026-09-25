import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/app_external_deps.dart';
import '../services/connectivity_checker.dart';

part 'is_admin_provider.g.dart';

/// Whether the signed-in user is a team admin (`users.is_admin`, set by hand
/// in the database — mp-144 clause 3). The flag gates admin-only surfaces
/// such as the meal review box; the server enforces the same flag in RLS,
/// so this read is only about what to show.
///
/// One small select per session (`keepAlive`): the cached `user_profiles`
/// row does not carry the flag and a Drift schema bump for a read-only
/// boolean is not worth it. Signed out, or any read failure, means `false`.
/// A sign-in or sign-out that changes the user re-reads, so an athlete who
/// signs in after an admin on the same device never inherits the box.
///
/// A read that failed (an offline start, Finding 89-010) still answers
/// `false` — the gate awaits it — and reads again once the network comes
/// back or the app next resumes, so one bad start does not hide Team review
/// for the whole session.
@Riverpod(keepAlive: true)
Future<bool> isAdmin(Ref ref) async {
  final deps = ref.watch(appExternalDepsProvider);
  final authUserId = deps.supabaseClient.auth.currentUser?.id;
  final sub = deps.supabaseClient.auth.onAuthStateChange.listen((state) {
    if (state.session?.user.id != authUserId) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
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
    _retryWhenReachable(ref);
    return false;
  }
}

/// Arm one re-read: the first of "the network came back" (an offline to
/// online change, never the state reported on subscribe) or "the app
/// resumed" invalidates the provider, whose rebuild drops both listeners.
/// Best-effort: if neither signal can be armed (no widgets binding, no
/// connectivity plugin) the answer stays `false`, as before.
void _retryWhenReachable(Ref ref) {
  var armed = true;
  var sawOffline = false;
  void retry() {
    if (!armed) return;
    armed = false;
    ref.invalidateSelf();
  }

  try {
    final network = ref.read(connectivityCheckerProvider).onlineChanges.listen((
      online,
    ) {
      // Only an offline-to-online change: the stream also reports the
      // current state on subscribe, and a read that failed while online
      // (a 5xx, a timeout) would otherwise re-read in a tight loop.
      if (!online) {
        sawOffline = true;
      } else if (sawOffline) {
        retry();
      }
    }, onError: (_) {});
    ref.onDispose(network.cancel);
  } catch (_) {}
  try {
    final lifecycle = AppLifecycleListener(onResume: retry);
    ref.onDispose(lifecycle.dispose);
  } catch (_) {}
}

/// `users.is_admin` as PostgREST returns it: `true`, `false`, `null` (an
/// older row or a schema without the column), or no row at all.
bool adminFlagFromUsersRow(Map<String, dynamic>? row) =>
    row?['is_admin'] == true;
