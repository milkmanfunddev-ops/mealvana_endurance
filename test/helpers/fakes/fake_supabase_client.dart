// Reusable fake SupabaseClient for widget/unit tests.
//
// Screens and controllers commonly read `supabaseClient.auth` (and its
// current user / session / auth-state stream). A bare mock returns null for
// `.auth`, which crashes with `type 'Null' is not a subtype of GoTrueClient`.
// `fakeSupabaseClient()` returns a client with those wired to safe no-op
// defaults (signed-out: no user, no session, empty auth-state stream).
//
// This resolves the long-standing "Supabase Auth Mocking" TODO in test/README.

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

/// A [SupabaseClient] mock with `auth` stubbed for the signed-out state:
/// no current user/session and an empty `onAuthStateChange` stream.
SupabaseClient fakeSupabaseClient({GoTrueClient? auth}) {
  final client = MockSupabaseClient();
  final goTrue = auth ?? fakeGoTrueClient();
  when(() => client.auth).thenReturn(goTrue);
  return client;
}

/// A [GoTrueClient] mock in the signed-out state.
GoTrueClient fakeGoTrueClient() {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.currentSession).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}
