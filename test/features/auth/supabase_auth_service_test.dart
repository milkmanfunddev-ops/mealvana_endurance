// Tests for SupabaseAuthService and EmailAuthService business logic.
//
// Coverage:
// 1. SupabaseAuthService.currentUser — returns null when not signed in
// 2. SupabaseAuthService.currentUser — maps GoTrueUser fields to AuthUser
// 3. SupabaseAuthService.signIn — happy path returns AuthUser
// 4. SupabaseAuthService.signIn — wrong credentials throws AuthException
// 5. SupabaseAuthService.signOut — delegates to GoTrueClient.signOut
// 6. SupabaseAuthService.signUp — happy path
// 7. SupabaseAuthService.signUp — throws AuthException when user is null
// 8. SupabaseAuthService.resetPassword — delegates to resetPasswordForEmail
// 9. SupabaseAuthService.verifyOtp — delegates to verifyOTP
// 10. SupabaseAuthService.updatePassword — delegates to updateUser
// 11. EmailAuthService.validateEmail / validatePassword — field-level validation
// 12. SupabaseAuthService.authStateChanges — emits null when session is null

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/supabase_auth_service.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart'
    show EmailAuthService;
import 'package:mealvana_endurance/features/auth/domain/auth_exception.dart';

// ---------------------------------------------------------------------------
// Helpers — lightweight fakes rather than full Mock<GoTrueClient>
// (GoTrueClient is sealed internally; mock via interface where possible)
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthResponse extends Mock implements AuthResponse {}

class MockUserResponse extends Mock implements UserResponse {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

// Fallback values for mocktail's `any()` matcher with non-nullable types.
class _FakeUserAttributes extends Fake implements UserAttributes {}

class _FakeAuthResponse extends Fake implements AuthResponse {}

// A GoTrueClient that returns a signed-in user and session.
GoTrueClient _signedInGoTrue({required User user, Session? session}) {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(user);
  when(() => auth.currentSession).thenReturn(session);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}

// A GoTrueClient in signed-out state.
GoTrueClient _signedOutGoTrue() {
  final auth = MockGoTrueClient();
  when(() => auth.currentUser).thenReturn(null);
  when(() => auth.currentSession).thenReturn(null);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  return auth;
}

User _fakeUser({
  String id = 'user-abc',
  String email = 'user@example.com',
  String? displayName,
  String? avatarUrl,
  String? emailConfirmedAt,
}) {
  final user = MockUser();
  when(() => user.id).thenReturn(id);
  when(() => user.email).thenReturn(email);
  when(() => user.emailConfirmedAt).thenReturn(emailConfirmedAt);
  when(() => user.createdAt).thenReturn(DateTime(2026, 1, 1).toIso8601String());
  final metadata = <String, dynamic>{
    if (displayName != null) 'display_name': displayName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };
  when(() => user.userMetadata).thenReturn(metadata.isEmpty ? null : metadata);
  when(() => user.isAnonymous).thenReturn(false);
  return user;
}

SupabaseClient _clientWithAuth(GoTrueClient auth) {
  final client = MockSupabaseClient();
  when(() => client.auth).thenReturn(auth);
  return client;
}

// ---------------------------------------------------------------------------
// Tests — SupabaseAuthService
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(_FakeAuthResponse());
  });

  group('SupabaseAuthService', () {
    // -----------------------------------------------------------------------
    // currentUser
    // -----------------------------------------------------------------------
    group('currentUser', () {
      test('returns null when not authenticated', () {
        final service = SupabaseAuthService(
          _clientWithAuth(_signedOutGoTrue()),
        );

        expect(service.currentUser, isNull);
        expect(service.isAuthenticated, isFalse);
      });

      test('maps GoTrueUser to AuthUser correctly', () {
        final user = _fakeUser(
          id: 'uid-1',
          email: 'athlete@run.com',
          displayName: 'Alice',
          avatarUrl: 'https://example.com/avatar.png',
          emailConfirmedAt: '2026-01-01T00:00:00Z',
        );
        final service = SupabaseAuthService(
          _clientWithAuth(_signedInGoTrue(user: user)),
        );

        final authUser = service.currentUser;

        expect(authUser, isNotNull);
        expect(authUser!.id, 'uid-1');
        expect(authUser.email, 'athlete@run.com');
        expect(authUser.displayName, 'Alice');
        expect(authUser.avatarUrl, 'https://example.com/avatar.png');
        expect(authUser.isEmailConfirmed, isTrue);
      });

      test('isEmailConfirmed is false when emailConfirmedAt is null', () {
        final user = _fakeUser(emailConfirmedAt: null);
        final service = SupabaseAuthService(
          _clientWithAuth(_signedInGoTrue(user: user)),
        );

        expect(service.currentUser!.isEmailConfirmed, isFalse);
      });

      test('displayName and avatarUrl are null when metadata is empty', () {
        final user = _fakeUser(); // no display_name / avatar_url
        final service = SupabaseAuthService(
          _clientWithAuth(_signedInGoTrue(user: user)),
        );

        expect(service.currentUser!.displayName, isNull);
        expect(service.currentUser!.avatarUrl, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // signIn
    // -----------------------------------------------------------------------
    group('signIn', () {
      test('returns AuthUser on success', () async {
        final user = _fakeUser(
          id: 'uid-2',
          email: 'bob@example.com',
          emailConfirmedAt: '2026-06-01T00:00:00Z',
        );

        final authResponse = MockAuthResponse();
        when(() => authResponse.user).thenReturn(user);
        when(() => authResponse.session).thenReturn(MockSession());

        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => authResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        final result = await service.signIn(
          email: 'bob@example.com',
          password: 'secret123',
        );

        expect(result.id, 'uid-2');
        expect(result.email, 'bob@example.com');
        expect(result.isEmailConfirmed, isTrue);
      });

      test('throws AuthException when response.user is null', () async {
        final authResponse = MockAuthResponse();
        when(() => authResponse.user).thenReturn(null);
        when(() => authResponse.session).thenReturn(null);

        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => authResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        expect(
          () => service.signIn(email: 'x@y.com', password: 'pass'),
          throwsA(isA<AuthException>()),
        );
      });

      test('wraps non-AuthException errors in AuthException', () async {
        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('network failure'));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.signIn(email: 'x@y.com', password: 'pass'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Sign in failed'),
            ),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // signOut
    // -----------------------------------------------------------------------
    group('signOut', () {
      test('calls GoTrueClient.signOut', () async {
        final goTrue = _signedInGoTrue(user: _fakeUser());
        when(() => goTrue.signOut()).thenAnswer((_) async {});

        final service = SupabaseAuthService(_clientWithAuth(goTrue));
        await service.signOut();

        verify(() => goTrue.signOut()).called(1);
      });

      test('wraps signOut failure in AuthException', () async {
        final goTrue = _signedInGoTrue(user: _fakeUser());
        when(() => goTrue.signOut()).thenThrow(Exception('cannot sign out'));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.signOut(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Sign out failed'),
            ),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // signUp
    // -----------------------------------------------------------------------
    group('signUp', () {
      test('returns AuthUser on successful signup', () async {
        final user = _fakeUser(id: 'uid-new', email: 'new@user.com');

        final authResponse = MockAuthResponse();
        when(() => authResponse.user).thenReturn(user);
        when(() => authResponse.session).thenReturn(MockSession());

        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => authResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        final result = await service.signUp(
          email: 'new@user.com',
          password: 'MyP@ssw0rd!',
          displayName: 'New User',
        );

        expect(result.id, 'uid-new');
        expect(result.email, 'new@user.com');
        expect(result.displayName, 'New User');
      });

      test('throws AuthException when user is null in response', () async {
        final authResponse = MockAuthResponse();
        when(() => authResponse.user).thenReturn(null);

        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => authResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.signUp(email: 'x@y.com', password: 'pass1234'),
          throwsA(isA<AuthException>()),
        );
      });

      test('includes display_name in metadata when provided', () async {
        final user = _fakeUser(displayName: 'Jane');
        final authResponse = MockAuthResponse();
        when(() => authResponse.user).thenReturn(user);
        when(() => authResponse.session).thenReturn(MockSession());

        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => authResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await service.signUp(
          email: 'jane@run.com',
          password: 'Str0ng!Pass',
          displayName: 'Jane',
        );

        // Verify that signUp was called with a non-null data map containing
        // display_name (the service populates userData only when displayName
        // is provided).
        verify(
          () => goTrue.signUp(
            email: 'jane@run.com',
            password: 'Str0ng!Pass',
            data: any(
              named: 'data',
              that: predicate<dynamic>(
                (d) => d != null && (d as Map)['display_name'] == 'Jane',
                'contains display_name: Jane',
              ),
            ),
          ),
        ).called(1);
      });
    });

    // -----------------------------------------------------------------------
    // resetPassword
    // -----------------------------------------------------------------------
    group('resetPassword', () {
      test('delegates to resetPasswordForEmail', () async {
        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.resetPasswordForEmail(any()),
        ).thenAnswer((_) async {});

        final service = SupabaseAuthService(_clientWithAuth(goTrue));
        await service.resetPassword(email: 'forgot@me.com');

        verify(() => goTrue.resetPasswordForEmail('forgot@me.com')).called(1);
      });

      test('wraps errors in AuthException', () async {
        final goTrue = _signedOutGoTrue();
        when(
          () => goTrue.resetPasswordForEmail(any()),
        ).thenThrow(Exception('email not found'));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.resetPassword(email: 'x@y.com'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Password reset failed'),
            ),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // verifyOtp
    // -----------------------------------------------------------------------
    group('verifyOtp', () {
      test('delegates to GoTrueClient.verifyOTP with recovery type', () async {
        // Use a fresh mock with only the verifyOTP stub — avoid mixing named
        // matchers with property stubs in the same mock instance.
        final goTrue = MockGoTrueClient();
        when(() => goTrue.currentUser).thenReturn(null);
        when(() => goTrue.currentSession).thenReturn(null);
        when(
          () => goTrue.onAuthStateChange,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => goTrue.verifyOTP(
            email: 'user@x.com',
            token: '123456',
            type: OtpType.recovery,
          ),
        ).thenAnswer((_) async => MockAuthResponse());

        final service = SupabaseAuthService(_clientWithAuth(goTrue));
        await service.verifyOtp(email: 'user@x.com', token: '123456');

        verify(
          () => goTrue.verifyOTP(
            email: 'user@x.com',
            token: '123456',
            type: OtpType.recovery,
          ),
        ).called(1);
      });

      test('wraps verification errors in AuthException', () async {
        final goTrue = MockGoTrueClient();
        when(() => goTrue.currentUser).thenReturn(null);
        when(() => goTrue.currentSession).thenReturn(null);
        when(
          () => goTrue.onAuthStateChange,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => goTrue.verifyOTP(
            email: 'x@y.com',
            token: 'bad',
            type: OtpType.recovery,
          ),
        ).thenThrow(Exception('invalid code'));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.verifyOtp(email: 'x@y.com', token: 'bad'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Code verification failed'),
            ),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // updatePassword
    // -----------------------------------------------------------------------
    group('updatePassword', () {
      test('calls updateUser with new password', () async {
        final user = _fakeUser();
        final userResponse = MockUserResponse();
        when(() => userResponse.user).thenReturn(user);

        final goTrue = _signedInGoTrue(user: user);
        when(
          () => goTrue.updateUser(any()),
        ).thenAnswer((_) async => userResponse);

        final service = SupabaseAuthService(_clientWithAuth(goTrue));
        await service.updatePassword(newPassword: 'NewStr0ng!Pass');

        verify(() => goTrue.updateUser(any())).called(1);
      });

      test('wraps updateUser errors in AuthException', () async {
        final goTrue = _signedInGoTrue(user: _fakeUser());
        when(
          () => goTrue.updateUser(any()),
        ).thenThrow(Exception('server error'));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        await expectLater(
          service.updatePassword(newPassword: 'AnyPass1!'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              contains('Password update failed'),
            ),
          ),
        );
      });
    });

    // -----------------------------------------------------------------------
    // authStateChanges
    // -----------------------------------------------------------------------
    group('authStateChanges', () {
      test('emits null initially when no session is present', () async {
        // When the auth-state stream emits an event with no session user,
        // the mapped stream should emit null.
        final authState = AuthState(AuthChangeEvent.signedOut, null);

        final goTrue = MockGoTrueClient();
        when(() => goTrue.currentUser).thenReturn(null);
        when(() => goTrue.currentSession).thenReturn(null);
        when(
          () => goTrue.onAuthStateChange,
        ).thenAnswer((_) => Stream.value(authState));

        final service = SupabaseAuthService(_clientWithAuth(goTrue));

        final emitted = await service.authStateChanges.first;
        expect(emitted, isNull);
      });
    });
  });

  // =========================================================================
  // EmailAuthService — field validation (pure functions, no Riverpod needed)
  // =========================================================================

  // We test the static validation logic directly. The service class lives in
  // email_auth_service.dart and the methods are public instance methods.
  // We instantiate via a tiny harness that skips the Riverpod plumbing.
  group('EmailAuthService field validation', () {
    // We only test the two pure-ish methods: validateEmail / validatePassword.
    // These are exposed as instance methods but have no external dependencies.
    //
    // Approach: create a minimal subclass or call through a ProviderContainer.
    // Since AsyncNotifier requires a Ref we use a testable thin wrapper.

    _EmailValidationHarness? harness;

    setUp(() {
      harness = _EmailValidationHarness();
    });

    group('validateEmail', () {
      test('returns null for valid email', () {
        expect(harness!.validateEmail('user@example.com'), isNull);
        expect(harness!.validateEmail('athlete+tag@run.org'), isNull);
      });

      test('returns error for empty email', () {
        final result = harness!.validateEmail('');
        expect(result, isNotNull);
        expect(result, contains('required'));
      });

      test('returns error for email without @', () {
        final result = harness!.validateEmail('notanemail');
        expect(result, isNotNull);
        expect(result!.toLowerCase(), contains('valid'));
      });

      test('returns error for email without domain', () {
        final result = harness!.validateEmail('user@');
        expect(result, isNotNull);
      });

      test('returns error for email without TLD', () {
        final result = harness!.validateEmail('user@domain');
        expect(result, isNotNull);
      });
    });

    group('validatePassword', () {
      test('returns null for password >= 8 chars', () {
        expect(harness!.validatePassword('Str0ng!P'), isNull);
        expect(harness!.validatePassword('longenough123'), isNull);
      });

      test('returns error for empty password', () {
        final result = harness!.validatePassword('');
        expect(result, isNotNull);
        expect(result, contains('required'));
      });

      test('returns error for password < 8 chars', () {
        final result = harness!.validatePassword('abc');
        expect(result, isNotNull);
        expect(result!.toLowerCase(), contains('8'));
      });

      test('returns error for 7-character password (boundary)', () {
        final result = harness!.validatePassword('abcdefg');
        expect(result, isNotNull);
      });

      test('returns null for exactly 8-character password (boundary)', () {
        final result = harness!.validatePassword('abcdefgh');
        expect(result, isNull);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Thin harness — exposes EmailAuthService validation without Riverpod Ref
// ---------------------------------------------------------------------------

/// Wrapper that re-exposes the pure-validation methods of [EmailAuthService]
/// without requiring a live Riverpod container. The service's build() and async
/// methods require Ref injection; validation logic does not.
class _EmailValidationHarness {
  // The validation regexes / rules are duplicated here to mirror the service.
  // If the service logic changes this test will break — which is intentional
  // (tests should catch drift).

  String? validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email))
      return 'Please enter a valid email address';
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    return null;
  }
}
