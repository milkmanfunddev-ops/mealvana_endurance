/// Thrown by AI edge-function clients when the server returns HTTP 402.
///
/// Construct from the JSON body returned by the edge function
/// (`insufficientCreditsBody` in `supabase/functions/_shared/ai/credits.ts`):
/// ```json
/// { "error": "insufficient_credits", "message": "...", "balance": 3, "cost": 10,
///   "allowance_monthly": 300, "allowance_expires_at": "2026-10-15T12:00:00Z" }
/// ```
/// The one client handler for it (`handleInsufficientCredits`) raises the
/// top-up sheet, never a gate (mp-282).
class InsufficientCreditsException implements Exception {
  const InsufficientCreditsException({
    required this.balance,
    required this.cost,
    required this.message,
    this.allowanceMonthly,
    this.allowanceRenewsAt,
  });

  /// The user's current credit balance at the time of the rejection.
  final int balance;

  /// The number of credits the operation would have consumed.
  final int cost;

  /// Human-readable explanation returned by the server.
  final String message;

  /// The monthly Allowance the subscription carries, when the server said.
  /// 0 means the wallet was never granted one; null means an older server.
  final int? allowanceMonthly;

  /// When the current Allowance window renews, when the server said.
  final DateTime? allowanceRenewsAt;

  /// Parse from an edge function 402 response body.
  factory InsufficientCreditsException.fromMap(Map<String, dynamic> map) {
    final renews = map['allowance_expires_at'];
    return InsufficientCreditsException(
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      message: (map['message'] as String?) ?? 'Not enough AI credits.',
      allowanceMonthly: (map['allowance_monthly'] as num?)?.toInt(),
      allowanceRenewsAt: renews is String ? DateTime.tryParse(renews) : null,
    );
  }

  @override
  String toString() =>
      'InsufficientCreditsException(balance: $balance, cost: $cost): $message';
}
