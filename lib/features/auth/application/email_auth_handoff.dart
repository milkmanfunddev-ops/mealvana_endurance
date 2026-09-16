import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'email_auth_handoff.g.dart';

/// Which email screen finished.
enum EmailAuthKind { login, signup }

/// One finished email flow. [seq] makes every success a new value, so a
/// listener sees the second login of a session as well as the first.
class EmailAuthHandoffEvent {
  const EmailAuthHandoffEvent(this.kind, this.seq);

  final EmailAuthKind kind;
  final int seq;

  @override
  bool operator ==(Object other) =>
      other is EmailAuthHandoffEvent && other.kind == kind && other.seq == seq;

  @override
  int get hashCode => Object.hash(kind, seq);
}

/// How the email login and signup screens tell the Log In screen beneath
/// them that they finished (2026-09-16: the first login came back to the
/// Log In screen and only the second went through).
///
/// The screens used to `pop(true)` and the Log In screen awaited the future
/// its `push` returned. That future is not reliable: whenever a dependency
/// above the Router changes while the pushed screen is up (the keyboard
/// closing, a theme or config rebuild), Flutter's Router re-parses the route
/// stack it last reported, and go_router 12 rebuilds every pushed route from
/// that encoded state with a fresh completer. The pop then completes a
/// completer nobody awaits and the Log In screen never moves. A sign-in that
/// takes a while (a fresh session, data migration, the first sync) leaves a
/// wide window for that; the quick second login slips through it.
///
/// So the screens report through this notifier instead, and the Log In
/// screen listens. They still pop, for the stack; nothing waits on it.
@Riverpod(keepAlive: true)
class EmailAuthHandoff extends _$EmailAuthHandoff {
  int _seq = 0;

  @override
  EmailAuthHandoffEvent? build() => null;

  void succeeded(EmailAuthKind kind) {
    state = EmailAuthHandoffEvent(kind, ++_seq);
  }
}
