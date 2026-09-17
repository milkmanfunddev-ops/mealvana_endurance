import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';

part 'tester_account_store.g.dart';

/// The server-side half of the 7-tap "Mark this device as internal" switch:
/// `users.is_internal` on the signed-in account.
///
/// The switch itself is per device and only decides what the app draws. The
/// photo function (`meal-photo`) gates every write on this column, so without
/// it a Tester sees the photo controls and every save is refused. Writing it
/// from the switch makes the two agree (Lee, 2026-09-17).
///
/// `users_update_own` already lets an account update its own row, this column
/// included, so this grants nothing a signed-in caller could not already do —
/// the same accepted risk as the 7-tap gesture itself (ADR 0003). No
/// entitlement reads the column any more, so it does not unlock Pro.
///
/// A plain `update`, never an upsert: it touches this one column and cannot
/// create a row. Remote-only on purpose — the column has no Drift mirror, and a
/// Tester needs to know now whether the server agrees, not after a queue drains.
class TesterAccountStore {
  const TesterAccountStore(this._supabase);

  final SupabaseClient _supabase;

  /// Sets `users.is_internal` for the signed-in account.
  ///
  /// Answers false when nobody is signed in, so there is no account to mark.
  /// Throws when the write fails or matches no row (RLS answers a refused
  /// update with zero rows rather than an error).
  Future<bool> write(bool isTester) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final rows = await _supabase
        .from('users')
        .update({'is_internal': isTester})
        .eq('id', userId)
        .select('id');
    if (rows.isEmpty) {
      throw StateError('users.is_internal update matched no row for $userId');
    }
    return true;
  }
}

@riverpod
TesterAccountStore testerAccountStore(Ref ref) =>
    TesterAccountStore(ref.watch(appExternalDepsProvider).supabaseClient);
