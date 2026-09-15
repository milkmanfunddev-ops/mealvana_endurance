/// Represents a user's AI credit wallet snapshot.
///
/// Read-only projection from the `token_wallets` Supabase table.
/// All mutation is performed server-side (by edge functions and webhooks).
///
/// Since ticket 20 (mp-281) the row also carries the subscription's monthly
/// Allowance: [allowance] is what is left of this period's grant and is PART
/// of [balance] (the server spends it before pack credits and forfeits it at
/// [allowanceRenewsAt]); [allowanceMonthly] is the size of the grant, the
/// number the top-up sheet shows; [packCredits] is the rest, which never
/// expires.
class CreditWallet {
  const CreditWallet({
    required this.balance,
    this.allowance = 0,
    this.allowanceMonthly = 0,
    this.allowanceRenewsAt,
    this.freePeriod,
    this.updatedAt,
  });

  /// Current credit balance (allowance + pack credits). Never negative from
  /// the server, but clamp on display just in case.
  final int balance;

  /// Credits left of this period's Allowance. Part of [balance].
  final int allowance;

  /// The monthly Allowance the subscription carries; 0 until first granted.
  final int allowanceMonthly;

  /// When the current Allowance window ends — the renewal date the sheet
  /// shows. Null when no window is open.
  final DateTime? allowanceRenewsAt;

  /// Human-readable label for the free tier period, if any (e.g. "trial").
  /// Null when the user is on a paid plan or has no free period configured.
  final String? freePeriod;

  /// Timestamp the wallet row was last modified on the server.
  final DateTime? updatedAt;

  /// Zero-balance wallet used as a safe fallback when no row exists yet.
  static const zero = CreditWallet(balance: 0);

  /// Whether the wallet has ever been granted an Allowance — i.e. whether
  /// the sheet has an allowance line to show.
  bool get hasAllowance => allowanceMonthly > 0;

  /// Pack credits: the part of [balance] that is not this period's
  /// Allowance. Never negative, even if a row arrives inconsistent.
  int get packCredits =>
      (balance - allowance).clamp(0, balance < 0 ? 0 : balance);

  /// Parse a wallet from a Supabase row map.
  factory CreditWallet.fromMap(Map<String, dynamic> map) {
    return CreditWallet(
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      allowance: (map['allowance'] as num?)?.toInt() ?? 0,
      allowanceMonthly: (map['allowance_monthly'] as num?)?.toInt() ?? 0,
      allowanceRenewsAt: map['allowance_expires_at'] != null
          ? DateTime.tryParse(map['allowance_expires_at'] as String)
          : null,
      freePeriod: map['free_period'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'CreditWallet(balance: $balance, allowance: $allowance/'
      '$allowanceMonthly, renews: $allowanceRenewsAt, freePeriod: $freePeriod)';
}
