/// What `redeem-code` answered for one Code (mp-458), read off the wire.
///
/// The function's answers (supabase/functions/redeem-code/handler.ts):
///
///   200 { ok: true, kind: 'coach' | 'giveaway', pro_days }
///   200 { ok: true, kind: 'paired', coach_user_id, coach_name } | { ok: true, kind: 'attributed' }
///   200 { ok: false, reason, message }   a refusal, with its plain reason;
///       `pro_active` also carries `pro_until` and `grant` (122-001)
///   400 invalid_input, no code (read as a not_found refusal)
///   400 code_too_long, over 32 characters (read as a too_long refusal)
///   403 sign_in_required · 401 unauthenticated
///   500 server_error · 502 store_unavailable
///
/// A refusal is an answer ([CodeRefused]); a non-2xx or no answer at all is a
/// [CodeRedeemFailure].
sealed class CodeRedemption {
  const CodeRedemption();

  /// Reads a 200 body. Anything that is not one of the shapes above is a
  /// [CodeRedeemFailure] (unavailable): the app never guesses at a grant.
  static CodeRedemption fromResponse(Object? data) {
    if (data is! Map) throw const CodeRedeemFailure.unavailable();
    if (data['ok'] == true) {
      final kind = switch (data['kind']) {
        'coach' => RedeemedKind.coach,
        'giveaway' => RedeemedKind.giveaway,
        'paired' => RedeemedKind.paired,
        'attributed' => RedeemedKind.attributed,
        _ => throw const CodeRedeemFailure.unavailable(),
      };
      final days = data['pro_days'];
      final coachName = data['coach_name'];
      return CodeRedeemed(
        kind: kind,
        proDays: days is num ? days.toInt() : 0,
        coachUserId: data['coach_user_id'] as String?,
        coachName: coachName is String && coachName.trim().isNotEmpty
            ? coachName.trim()
            : null,
      );
    }
    if (data['ok'] == false) {
      final until = data['pro_until'];
      return CodeRefused(
        reason: CodeRefusal.fromWire(data['reason']),
        serverMessage: data['message'] is String
            ? data['message'] as String
            : null,
        proUntil: until is String ? DateTime.tryParse(until)?.toUtc() : null,
        proIsGrant: data['grant'] == true,
      );
    }
    throw const CodeRedeemFailure.unavailable();
  }
}

/// What a Code did.
enum RedeemedKind {
  /// A coach entered their own Code: marked coach, [CodeRedeemed.proDays] of
  /// `pro` (30).
  coach,

  /// A giveaway Code: [CodeRedeemed.proDays] of `pro` (365).
  giveaway,

  /// A coach's Code entered by an athlete: paired with that coach at once
  /// (Lee, 2026-09-26: a coach's code is their invitation).
  paired,

  /// An influencer's Code: only who referred the account is recorded.
  attributed,
}

class CodeRedeemed extends CodeRedemption {
  const CodeRedeemed({
    required this.kind,
    this.proDays = 0,
    this.coachUserId,
    this.coachName,
  });

  final RedeemedKind kind;

  /// Days of `pro` granted; 0 when the Code grants none.
  final int proDays;

  /// The coach a [RedeemedKind.paired] Code paired with.
  final String? coachUserId;

  /// That coach's name, as the server holds it; null when it has none.
  final String? coachName;

  /// Whether RevenueCat now holds a grant the SDK's cache does not know of.
  bool get grantsPro => proDays > 0;
}

/// The plain reasons `redeem-code` refuses a Code with (its `REFUSALS`).
enum CodeRefusal {
  notFound,
  notYetValid,
  expired,
  used,
  alreadyRedeemed,
  ownCode,

  /// A coach Code from a coach the athlete has already asked to pair with
  /// (pending or active); no claim is spent (11-002, ticket 95).
  alreadyPaired,

  /// Longer than any Code can be (the function's 400 `code_too_long`); the
  /// entry caps the field, so only a pasted Code with spaces can reach it.
  tooLong,

  /// A giveaway while any Pro is active: a running Grant or a paying
  /// subscription. Nothing is spent (122-001; Lee, 2026-09-26).
  proActive,

  /// A reason this build does not know; the server's own message is shown.
  other;

  static CodeRefusal fromWire(Object? reason) => switch (reason) {
    'not_found' => notFound,
    'not_yet_valid' => notYetValid,
    'expired' => expired,
    'used' => used,
    'already_redeemed' => alreadyRedeemed,
    'own_code' => ownCode,
    'already_paired' => alreadyPaired,
    'too_long' => tooLong,
    'pro_active' => proActive,
    _ => other,
  };
}

class CodeRefused extends CodeRedemption {
  const CodeRefused({
    required this.reason,
    this.serverMessage,
    this.proUntil,
    this.proIsGrant = false,
  });

  final CodeRefusal reason;

  /// The function's own words, used only for [CodeRefusal.other].
  final String? serverMessage;

  /// For [CodeRefusal.proActive]: when the running Pro ends, and whether it
  /// is a Grant (free Pro) rather than a paying subscription.
  final DateTime? proUntil;
  final bool proIsGrant;
}

/// Why no answer came back.
enum CodeRedeemFailureKind {
  /// 403 `sign_in_required` (anonymous) or 401: only a signed-in account can
  /// redeem a Code (mp-458 §2).
  signInRequired,

  /// Offline, a timeout, the store or the server failing (a claim is
  /// released on the server, so the Code can be tried again).
  unavailable,
}

class CodeRedeemFailure implements Exception {
  const CodeRedeemFailure(this.kind);
  const CodeRedeemFailure.unavailable()
    : kind = CodeRedeemFailureKind.unavailable;
  const CodeRedeemFailure.signInRequired()
    : kind = CodeRedeemFailureKind.signInRequired;

  final CodeRedeemFailureKind kind;

  @override
  String toString() => 'CodeRedeemFailure(${kind.name})';
}
