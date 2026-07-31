import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/credit_wallet.dart';

part 'credits_repository.g.dart';

@riverpod
CreditsRepository creditsRepository(Ref ref) {
  return CreditsRepository(supabase: ref.watch(supabaseClientProvider));
}

/// Remote-only repository for reading the authenticated user's credit wallet.
///
/// The `token_wallets` and `token_ledger` tables are read-only from the client
/// (RLS: read-own). All mutations are performed server-side by edge functions
/// and RevenueCat webhooks.
class CreditsRepository {
  CreditsRepository({required SupabaseClient supabase}) : _supabase = supabase;

  final SupabaseClient _supabase;

  /// Whether a real (non-anonymous) user is signed in.
  ///
  /// Purchases and the wallet are meaningless without one: the RevenueCat
  /// webhook maps `app_user_id` straight onto `auth.users.id`, so a purchase
  /// made without a signed-in user credits nobody and the money is simply gone.
  bool get hasAuthenticatedUser {
    final user = _supabase.auth.currentUser;
    return user != null && user.id.isNotEmpty;
  }

  /// The signed-in user's id, or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Provision the wallet and grant this month's free credits, returning the
  /// resulting balance (null on any failure).
  ///
  /// The wallet used to be created lazily by the first AI call, so a new user
  /// saw a balance of 0 — and a "You're out of tokens" prompt — until they ran
  /// an analysis, at which point it jumped straight to `grant - 1`. The grant
  /// RPCs take a user id as a parameter and are `service_role`-only for that
  /// reason, so this goes through the `ensure-credits` edge function, which
  /// derives the user from the JWT. Idempotent: at most one grant per calendar
  /// month, so it is safe to call on every app start.
  Future<int?> ensureWallet() async {
    if (!hasAuthenticatedUser) return null;

    try {
      final res = await _supabase.functions.invoke('ensure-credits');
      final data = res.data;
      if (data is Map && data['balance'] is int) return data['balance'] as int;
      return null;
    } catch (e) {
      // Non-fatal: the AI functions still provision on first use, so a failure
      // here costs a stale zero on screen, never a lost grant.
      debugPrint('[CreditsRepository] ensureWallet error: $e');
      return null;
    }
  }

  /// Fetch the current user's wallet.
  ///
  /// Returns [CreditWallet.zero] when:
  /// - No user is signed in.
  /// - No wallet row exists yet (first-time user before server bootstrap).
  Future<CreditWallet> fetchWallet() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return CreditWallet.zero;

    try {
      final row = await _supabase
          .from('token_wallets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return CreditWallet.zero;
      return CreditWallet.fromMap(row);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CreditsRepository] fetchWallet error: $e');
      }
      // Return safe default so the app never crashes on a wallet read error.
      return CreditWallet.zero;
    }
  }

  /// Subscribe to live changes on the current user's wallet row.
  ///
  /// The wallet is credited server-side by the RevenueCat webhook, and delivery
  /// is not bounded — a healthy credit lands in seconds, but a purchase made
  /// before validation was configured once took 13 minutes. Any client-side
  /// poll picks a timeout and is wrong on either side of it; a Postgres
  /// realtime subscription instead delivers the new balance the instant the
  /// webhook writes it (`token_wallets` is in the `supabase_realtime`
  /// publication, and RLS scopes events to the user's own row).
  ///
  /// Returns null when nobody is signed in. Callers own the channel and must
  /// [SupabaseClient.removeChannel] it when re-subscribing.
  RealtimeChannel? subscribeToWallet(void Function(CreditWallet) onChange) {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return _supabase
        .channel('token_wallet:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'token_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty) return;
            try {
              onChange(CreditWallet.fromMap(payload.newRecord));
            } catch (e) {
              debugPrint('[CreditsRepository] realtime payload parse: $e');
            }
          },
        )
        .subscribe();
  }

  /// Remove a channel previously returned by [subscribeToWallet].
  void removeChannel(RealtimeChannel channel) {
    _supabase.removeChannel(channel);
  }

  /// Fetch the most recent [limit] ledger entries for the current user.
  ///
  /// Returns an empty list when no user is signed in or on any error.
  Future<List<Map<String, dynamic>>> recentLedger({int limit = 20}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _supabase
          .from('token_ledger')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CreditsRepository] recentLedger error: $e');
      }
      return [];
    }
  }
}
