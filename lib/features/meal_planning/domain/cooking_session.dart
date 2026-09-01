/// `Session` in `contracts.ts` — which batch-cooking session a plan meal is
/// made in. `null` on the wire means "no session" (batch cooking off).
enum CookingSession {
  cookSun('cook-sun'),
  topupWed('topup-wed'),
  freshFri('fresh-fri');

  const CookingSession(this.wire);

  final String wire;

  static CookingSession? fromWire(String? value) {
    if (value == null) return null;
    for (final v in CookingSession.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}
