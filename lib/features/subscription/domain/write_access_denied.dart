/// A write refused because the account may not write right now (mp-457 §4:
/// lapsed, or an unresolved gate). Thrown by `requireWriteAccess` after the
/// paywall has been opened, for a controller method that must answer with a
/// value and so cannot simply return. A screen that catches it has nothing
/// left to do: the paywall is already up.
class WriteAccessDenied implements Exception {
  const WriteAccessDenied();

  @override
  String toString() => 'WriteAccessDenied: the plan has ended (mp-457)';
}
