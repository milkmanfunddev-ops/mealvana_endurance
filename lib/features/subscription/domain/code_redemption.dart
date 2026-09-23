/// What `redeem-code` answered for one Code (mp-458), read off the wire.
///
/// The function's answers (supabase/functions/redeem-code/handler.ts):
///
///   200 { ok: true, kind: 'coach' | 'giveaway', pro_days }
///   200 { ok: true, kind: 'paired', coach_user_id } | { ok: true, kind: 'attributed' }
///   200 { ok: false, reason, message }   a refusal, with its plain reason
///   403 sign_in_required · 401 unauthenticated · 400 invalid_input
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
      return CodeRedeemed(
        kind: kind,
        proDays: days is num ? days.toInt() : 0,
        coachUserId: data['coach_user_id'] as String?,
      );
    }
    if (data['ok'] == false) {
      return CodeRefused(
        reason: CodeRefusal.fromWire(data['reason']),
        serverMessage: data['message'] is String
            ? data['message'] as String
            : null,
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

  /// A coach's Code entered by an athlete: a pending pairing with that coach.
  paired,

  /// An influencer's Code: only who referred the account is recorded.
  attributed,
}

class CodeRedeemed extends CodeRedemption {
  const CodeRedeemed({required this.kind, this.proDays = 0, this.coachUserId});

  final RedeemedKind kind;

  /// Days of `pro` granted; 0 when the Code grants none.
  final int proDays;

  /// The coach a [RedeemedKind.paired] Code asked to pair with.
  final String? coachUserId;

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

  /// A reason this build does not know; the server's own message is shown.
  other;

  static CodeRefusal fromWire(Object? reason) => switch (reason) {
    'not_found' => notFound,
    'not_yet_valid' => notYetValid,
    'expired' => expired,
    'used' => used,
    'already_redeemed' => alreadyRedeemed,
    'own_code' => ownCode,
    _ => other,
  };
}

class CodeRefused extends CodeRedemption {
  const CodeRefused({required this.reason, this.serverMessage});

  final CodeRefusal reason;

  /// The function's own words, used only for [CodeRefusal.other].
  final String? serverMessage;
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
