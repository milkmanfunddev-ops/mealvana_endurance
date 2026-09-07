import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// The auth identity the wallet belongs to, as a rebuild signal.
///
/// [CreditsController.build] watches this so a session APPEARING (anonymous
/// sign-in at the end of onboarding), CHANGING (log out → log in) or ENDING
/// rebuilds the controller — which re-runs the monthly ensure/grant, rebinds
/// the realtime channel to the right user, and re-reads the wallet. Before
/// this existed the only thing that ever invalidated the controller was a
/// purchase, which is why balances "reappeared after buying".
@Riverpod(keepAlive: true)
Stream<String?> creditsAuthUserId(Ref ref) {
  return ref.watch(creditsRepositoryProvider).authUserIdChanges;
}

@Riverpod(keepAlive: true)
class CreditsController extends _$CreditsController {
  CreditsRepository get _repo => ref.read(creditsRepositoryProvider);

  /// Live wallet-row subscription; replaced whenever [build] reruns.
  RealtimeChannel? _walletChannel;

  /// Foreground hook; recreated with the notifier.
  AppLifecycleListener? _lifecycle;

  /// Never throws — see the class doc. A wallet read failure yields a zero
  /// balance, not an [AsyncError].
  @override
  FutureOr<CreditWallet> build() async {
    // Rebuild whenever the auth identity changes — the value itself is not
    // needed (the repository reads the live session); the WATCH is the fix.
    ref.watch(creditsAuthUserIdProvider);

    _listenForRemoteCredits();

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

  /// Keep the balance honest without user action.
  ///
  /// Two channels, because webhook latency is unbounded (a credit has taken
  /// anywhere from 12 seconds to 13 minutes to land):
  ///  - a Postgres realtime subscription on the user's `token_wallets` row, so
  ///    a webhook write updates the pill the moment it happens; and
  ///  - a refresh on app foreground, covering credits that landed while the
  ///    app was backgrounded or the socket was down.
  ///
  /// Without these, the balance a keepAlive controller cached at launch was
  /// simply what the user saw until they restarted the app — a tester who
  /// bought tokens watched the store say "success" while the pill never moved.
  void _listenForRemoteCredits() {
    final old = _walletChannel;
    if (old != null) {
      _repo.removeChannel(old);
      _walletChannel = null;
    }
    _walletChannel = _repo.subscribeToWallet((wallet) {
      debugPrint(
        '[CreditsController] wallet updated remotely → ${wallet.balance}',
      );
      state = AsyncData(wallet);
    });

    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(onResume: () => refresh());
  }

  /// Re-fetch the wallet from Supabase and update state.
  ///
  /// A plain read — never the provisioning call. Provisioning is handled by
  /// [build] at most once per user per calendar month.
  Future<void> refresh() async {
    // No AsyncLoading flash: this also runs on every app foreground now, and
    // blanking the pill each time reads as the balance vanishing. Fetch first,
    // swap state after.
    final fresh = await AsyncValue.guard(() => _repo.fetchWallet());
    // A background refresh must never replace a real balance with an error —
    // stale beats broken for a number that changes this rarely.
    if (fresh.hasError && state.hasValue) return;
    state = fresh;
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
