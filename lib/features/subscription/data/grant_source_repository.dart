import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../domain/grant.dart';

part 'grant_source_repository.g.dart';

/// Reads its Supabase client from [appExternalDepsProvider] (the seam the
/// widget-test harness mocks) rather than `Supabase.instance`.
@riverpod
GrantSourceRepository grantSourceRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return GrantSourceRepository(supabase: deps.supabaseClient);
}

/// Where the account's Grants came from, as the server recorded them
/// (`public.pro_grants`, mp-615): one row per grant the server made, written
/// by grace-claim, redeem-code and the flip-day grace run. Each account reads
/// only its own rows (RLS).
///
/// A read, asked when the Subscription screen shows a Grant. Nothing is
/// mirrored in Drift: offline, or on any failure, it answers no records and
/// the screen falls back to reading the source from the Grant's length.
class GrantSourceRepository {
  GrantSourceRepository({
    required SupabaseClient supabase,
    Duration timeout = const Duration(seconds: 5),
    @visibleForTesting String? Function()? currentUserId,
  }) : _supabase = supabase,
       _timeout = timeout,
       _currentUserId = currentUserId ?? (() => supabase.auth.currentUser?.id);

  final SupabaseClient _supabase;
  final Duration _timeout;
  final String? Function() _currentUserId;

  /// How many of the newest rows are read: enough to pass a row or two from
  /// earlier Grants to reach the running one.
  static const int _limit = 5;

  /// The signed-in account's newest Grant records, newest first; empty when
  /// signed out, offline, or the read fails.
  Future<List<GrantRecord>> recentGrants() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return const [];
      final rows = await _supabase
          .from('pro_grants')
          .select('source, pro_days, granted_at')
          .eq('user_id', userId)
          .order('granted_at', ascending: false)
          .limit(_limit)
          .timeout(_timeout);
      return [
        for (final row in rows)
          if (GrantRecord.fromRow(row) case final record?) record,
      ];
    } catch (e) {
      debugPrint('[GrantSourceRepository] pro_grants read failed: $e');
      return const [];
    }
  }
}
