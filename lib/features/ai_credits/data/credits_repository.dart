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
