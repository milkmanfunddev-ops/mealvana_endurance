import 'credit_wallet.dart';

/// What the athlete may see of the monthly Vana budget (mp-430 clause 8,
/// mp-436 clause 3): the share of this month used, when it refills, and any
/// bought extra as a share of a month. Never a dollar figure, never a count
/// of turns or credits.
///
/// The server already computes exactly this (`budgetStatus` in
/// `supabase/functions/_shared/ai/allowance.ts`) and `ensure-credits` returns
/// it. The same arithmetic lives here because the wallet row itself arrives
/// by two other doors the app cannot re-shape from this ticket — the
/// PostgREST read in `CreditsRepository.fetchWallet` and the realtime channel
/// — and one formula for all three is the only way the bar cannot disagree
/// with itself mid-session. Keep it in step with `allowance.ts`; the unit
/// test mirrors that file's cases.
class BudgetShare {
  const BudgetShare({
    required this.shareUsed,
    required this.refillAt,
    required this.boughtExtraShare,
    bool? spent,
  }) : _spent = spent;

  /// 0..1 of this period's budget spent. Null when no budget window is open
  /// (never granted, or lapsed), which is the one case with nothing to say
  /// about a month.
  final double? shareUsed;

  /// When the current window ends and the month refills. Null when none is
  /// open.
  final DateTime? refillAt;

  /// Unspent bought budget as a share of a month: the $4.99 pack is 0.25.
  /// Bought budget never expires (Apple 3.1.1), so it has no date.
  final double boughtExtraShare;

  final bool? _spent;

  /// Whether there is a month to show a bar for.
  bool get hasWindow => shareUsed != null;

  /// What is left to spend, as a share of a month: the rest of this month
  /// plus anything bought. This is the number the pill shows.
  double get shareLeft => (1 - (shareUsed ?? 1)) + boughtExtraShare;

  /// There is nothing left to spend — the next call gets the top-up sheet
  /// (mp-430 clause 6). A wallet that never had a month counts as spent: it
  /// has nothing either. What the screen SAYS about it differs, which is
  /// [hasWindow]'s job, not this one's.
  ///
  /// Read from the raw balance when the row gave one, never from the rounded
  /// shares: a wallet with a cent left reads "100% used" and is still not
  /// spent, so the server would accept its next call (mp-436 clause 1).
  bool get isSpent => _spent ?? shareLeft <= 0;

  @override
  String toString() =>
      'BudgetShare(used: $shareUsed, refills: $refillAt, '
      'bought: $boughtExtraShare)';
}

/// The monthly budget, in the wallet's unit (whole micro-dollars).
///
/// Mirrors `DEFAULT_MONTHLY_BUDGET` in `allowance.ts` ($4.00 a month, mp-430
/// clause 2). It is used only as the denominator for bought extra, so a
/// project that overrides the server's `AI_MONTHLY_BUDGET` would shift that
/// one line and nothing else. The share of the month used never reads it —
/// that comes from the grant the row itself carries.
const int kMonthlyBudgetMicros = 4000000;

/// Round a share to whole percent, the precision the screen shows.
double _wholePercent(double n) => (n * 100).round() / 100;

/// Derive what the athlete may see from a wallet row.
BudgetShare budgetShareOf(CreditWallet wallet) {
  final balance = wallet.balance < 0 ? 0 : wallet.balance;
  final allowance = wallet.allowance < 0 ? 0 : wallet.allowance;
  final monthly = wallet.allowanceMonthly;
  final windowOpen = monthly > 0 && wallet.allowanceRenewsAt != null;

  final used = windowOpen
      ? _wholePercent((1 - allowance / monthly).clamp(0.0, 1.0))
      : null;
  final bought = balance - allowance;

  return BudgetShare(
    shareUsed: used,
    refillAt: wallet.allowanceRenewsAt,
    boughtExtraShare: bought <= 0
        ? 0
        : _wholePercent(bought / kMonthlyBudgetMicros),
    spent: balance <= 0,
  );
}

/// A share of a month as whole percent, for display: 0.25 → 25.
int percentOf(double share) => (share * 100).round();
