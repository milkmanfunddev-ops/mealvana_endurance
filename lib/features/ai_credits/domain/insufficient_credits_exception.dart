/// Thrown by AI edge-function clients when the server returns HTTP 402.
///
/// Construct from the JSON body returned by the edge function:
/// ```json
/// { "error": "insufficient_credits", "message": "...", "balance": 3, "cost": 10 }
/// ```
class InsufficientCreditsException implements Exception {
  const InsufficientCreditsException({
    required this.balance,
    required this.cost,
    required this.message,
  });

  /// The user's current credit balance at the time of the rejection.
  final int balance;

  /// The number of credits the operation would have consumed.
  final int cost;

  /// Human-readable explanation returned by the server.
  final String message;

  /// Parse from an edge function 402 response body.
  factory InsufficientCreditsException.fromMap(Map<String, dynamic> map) {
    return InsufficientCreditsException(
      balance: (map['balance'] as num?)?.toInt() ?? 0,
      cost: (map['cost'] as num?)?.toInt() ?? 0,
      message: (map['message'] as String?) ?? 'Not enough AI credits.',
    );
  }

  @override
  String toString() =>
      'InsufficientCreditsException(balance: $balance, cost: $cost): $message';
}
