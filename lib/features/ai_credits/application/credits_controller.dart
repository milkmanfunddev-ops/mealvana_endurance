import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/preferences_service.dart';
import '../data/credits_repository.dart';
import '../domain/credit_wallet.dart';

part 'credits_controller.g.dart';

/// Exposes the current user's credit [CreditWallet].
///
/// **This is the single in-memory cache of the balance for the whole session.**
/// It is `keepAlive` because several widgets watch it independently — the token
/// pill on both meal screens, the top-up sheet, the buy-credits screen — and
/// under autoDispose the provider was rebuilt from scratch every time the last
/// of them unmounted. Each rebuild meant another network round trip just to
/// re-learn a number that had not changed. Now it builds once and every watcher
/// reads the same cached value; use [refresh] when something may have changed
/// it (a purchase landing, an analysis spending a token).
///
/// **[build] must never throw.** With `keepAlive`, a provider whose initial
/// build errors leaves `creditsControllerProvider.future` permanently
/// uncompleted (the state sits at `AsyncLoading` carrying the error, even with
/// a listener attached). [PurchaseController] awaits that future while polling
/// for the post-purchase balance, so a throwing build would hang a purchase
/// forever instead of failing it. A wallet we cannot read is reported as a zero
/// balance, which is also the better user-facing outcome: a transient network
/// error should show a stale number, not put the whole credits UI in an error
/// state.
@Riverpod(keepAlive: true)
class CreditsController extends _$CreditsController {
  CreditsRepository get _repo => ref.read(creditsRepositoryProvider);

  /// Never throws — see the class doc. A wallet read failure yields a zero
  /// balance, not an [AsyncError].
  @override
  FutureOr<CreditWallet> build() async {
    try {
      final balance = await _ensureOncePerMonth();
      if (balance != null) return CreditWallet(balance: balance);
      return await _repo.fetchWallet();
    } catch (e) {
      // Both repository calls already swallow their own errors, so reaching
      // here means something unexpected. Degrade rather than error out.
      debugPrint('[CreditsController] build failed, showing zero: $e');
      return CreditWallet.zero;
    }
  }

  /// Re-fetch the wallet from Supabase and update state.
  ///
  /// A plain read — never the provisioning call. Provisioning is handled by
  /// [build] at most once per user per calendar month.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchWallet());
  }

  /// Provision the wallet + grant this month's free credits, but at most once
  /// per user per calendar month on this device.
  ///
  /// Returns the provisioned balance, or null when the call was skipped or
  /// failed — in which case the caller falls back to a plain read.
  ///
  /// Without this guard the wallet used to be provisioned lazily by the first
  /// AI call, so a brand-new user saw a balance of 0 and a "You're out of
  /// tokens" prompt while their free grant sat unissued. Calling the edge
  /// function on every build fixed that but replaced it with a round trip per
  /// widget mount. The server-side grant is already idempotent for the month
  /// (`token_wallets.free_period`), so the marker here is purely about not
  /// paying for a call whose answer we can predict.
  Future<int?> _ensureOncePerMonth() async {
    final userId = _repo.currentUserId;
    if (userId == null || userId.isEmpty) return null;

    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final stamp = '$userId|$period';

    final prefs = ref.read(preferencesServiceProvider);
    if (prefs.creditsEnsuredStamp == stamp) return null;

    final balance = await _repo.ensureWallet();
    if (balance == null) return null;

    // Only mark it done once the server has actually answered, so a failed
    // call is retried on the next launch rather than suppressed for a month.
    await prefs.setCreditsEnsuredStamp(stamp);
    return balance;
  }
}
