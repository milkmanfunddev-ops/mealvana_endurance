/// Represents a user's AI credit wallet snapshot.
///
/// Read-only projection from the `token_wallets` Supabase table.
/// All mutation is performed server-side (by edge functions and webhooks).
class CreditWallet {
  const CreditWallet({
    required this.balance,
    this.freePeriod,
    this.updatedAt,
  });

  /// Current credit balance. Never negative from the server, but clamp on
  /// display just in case.
  final int balance;

  /// Human-readable label for the free tier period, if any (e.g. "trial").
  /// Null when the user is on a paid plan or has no free period configured.
  final String? freePeriod;

  /// Timestamp the wallet row was last modified on the server.
  final DateTime? updatedAt;

  /// Zero-balance wallet used as a safe fallback when no row exists yet.
  static const zero = CreditWallet(balance: 0);

  /// Parse a wallet from a Supabase row map.
  factory CreditWallet.fromMap(Map<String, dynamic> map) {
    return CreditWallet(
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      freePeriod: map['free_period'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'CreditWallet(balance: $balance, freePeriod: $freePeriod)';
}
