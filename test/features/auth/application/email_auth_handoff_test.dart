/// The email screens report success through [emailAuthHandoffProvider], not
/// through the future `push` returns (which go_router 12 can orphan).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/application/email_auth_handoff.dart';

void main() {
  test('starts silent and reports every success as a new value', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final seen = <EmailAuthHandoffEvent?>[];
    c.listen(emailAuthHandoffProvider, (_, next) => seen.add(next));

    expect(c.read(emailAuthHandoffProvider), isNull);

    final handoff = c.read(emailAuthHandoffProvider.notifier);
    handoff.succeeded(EmailAuthKind.login);
    handoff.succeeded(EmailAuthKind.login); // the second login of a session
    handoff.succeeded(EmailAuthKind.signup);

    expect(seen.map((e) => e!.kind), [
      EmailAuthKind.login,
      EmailAuthKind.login,
      EmailAuthKind.signup,
    ]);
    // Two logins in a row are two events, never one collapsed value.
    expect(seen[0], isNot(equals(seen[1])));
  });
}
