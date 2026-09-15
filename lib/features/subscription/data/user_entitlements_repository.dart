import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';

part 'user_entitlements_repository.g.dart';

/// Reads its Supabase client from [appExternalDepsProvider] (the seam the
/// widget-test harness mocks) rather than `Supabase.instance`.
@riverpod
UserEntitlementsRepository userEntitlementsRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return UserEntitlementsRepository(supabase: deps.supabaseClient);
}

/// The auth-identity seam of the subscription feature: who is signed in,
/// whether they are anonymous, and when that changes.
///
/// The server's `user_entitlements` table is a two-field cache of RevenueCat
/// that only the webhook writes and only the edge functions read (mp-285).
/// The client never reads it: the SDK's cached entitlement is the gate
/// (mp-284), so there is no remote read, no Drift mirror and no tester
/// mirror here any more.
class UserEntitlementsRepository {
  UserEntitlementsRepository({required SupabaseClient supabase})
    : _supabase = supabase;

  final SupabaseClient _supabase;

  /// The signed-in user's id, or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Whether the session is a Supabase *anonymous* user. Purchases are refused
  /// for them for the same reason as credit packs: the webhook maps
  /// `app_user_id` onto `auth.users.id`, and signing in to an existing account
  /// later swaps the id and strands the subscription.
  bool get isAnonymousUser => _supabase.auth.currentUser?.isAnonymous ?? false;

  /// Auth identity as a stream (null on sign-out), distinct so token refreshes
  /// don't chatter — the rebuild signal for the status provider.
  Stream<String?> get authUserIdChanges => _supabase.auth.onAuthStateChange
      .map((s) => s.session?.user.id)
      .distinct();
}
