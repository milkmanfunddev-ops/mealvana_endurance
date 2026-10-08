/// Ticket 36: a fresh login carries the session address onto the profile row,
/// except an Apple private-relay session address never buries a real contact
/// email the athlete stored. Drives the real `AuthMigrationService`
/// (`completeAuthentication`, fresh-login branch); only the repository, the
/// Supabase client and the reporter are faked.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/application/auth_migration_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../../helpers/fixtures/user_fixtures.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockDatabase extends Mock implements AppDatabase {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockReport extends Mock implements Report {}

void main() {
  late _MockUserRepository repo;
  late _MockReport report;
  late _MockGoTrue auth;
  late AuthMigrationService service;
  UserProfile? saved;

  setUpAll(() => registerFallbackValue(UserFixtures.oauthUser()));

  setUp(() {
    saved = null;
    repo = _MockUserRepository();
    report = _MockReport();
    auth = _MockGoTrue();
    final client = _MockSupabase();
    when(() => client.auth).thenReturn(auth);
    when(
      () => report.note(
        any(),
        area: any(named: 'area'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
    service = AuthMigrationService(
      userRepository: repo,
      database: _MockDatabase(),
      supabase: client,
      report: report,
    );
  });

  void givenSession(String? email) {
    final user = _MockUser();
    when(() => user.email).thenReturn(email);
    when(() => auth.currentUser).thenReturn(user);
  }

  void givenStored(String? email) {
    when(() => repo.fetchAndSaveRemoteProfile('u1')).thenAnswer(
      (_) async => UserFixtures.oauthUser(
        id: 'u1',
        authProvider: 'apple',
      ).copyWith(email: email),
    );
  }

  Future<void> freshLogin() => service.completeAuthentication(
    previousUserId: null,
    wasAnonymous: false,
    newUserId: 'u1',
    authProvider: 'apple',
  );

  test('a relay session address keeps a stored contact email', () async {
    givenStored('lee@example.com');
    givenSession('x1y2@privaterelay.appleid.com');

    await freshLogin();

    expect(saved, isNotNull);
    expect(saved!.email, 'lee@example.com');
    // D9: the guard writes down that it fired.
    verify(
      () => report.note(
        any(that: contains('private-relay')),
        area: 'auth',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  test(
    'a real session address still replaces an empty profile email',
    () async {
      givenStored(null);
      givenSession('lee@example.com');

      await freshLogin();

      expect(saved!.email, 'lee@example.com');
      verifyNever(
        () => report.note(
          any(),
          area: any(named: 'area'),
          data: any(named: 'data'),
        ),
      );
    },
  );

  test('a relay session address fills an empty profile email', () async {
    // Nothing to protect: the relay is the only address there is. Settings
    // reads a stored relay as an empty contact email.
    givenStored(null);
    givenSession('x1y2@privaterelay.appleid.com');

    await freshLogin();

    expect(saved!.email, 'x1y2@privaterelay.appleid.com');
  });

  test('no session address keeps the stored one', () async {
    givenStored('lee@example.com');
    givenSession(null);

    await freshLogin();

    expect(saved!.email, 'lee@example.com');
  });

  // Ticket 56 review: the profile save lands after the signedIn event's
  // snapshot refresh, so the service asks for one more after it saves.
  group('startup snapshot refresh after the profile save', () {
    late List<(String, bool)> refreshes;

    setUp(() {
      refreshes = [];
      service = AuthMigrationService(
        userRepository: repo,
        database: _MockDatabase(),
        supabase: _MockSupabase()..stub(auth),
        report: report,
        refreshStartupSnapshot: (reason) async =>
            refreshes.add((reason, saved != null)),
      );
      givenStored('lee@example.com');
      givenSession('lee@example.com');
    });

    test('a fresh login refreshes once, after the save', () async {
      await freshLogin();
      expect(refreshes, [('sign_in_profile_saved', true)]);
    });

    test('an anonymous upgrade (linked in place) refreshes once, after the '
        'save', () async {
      await service.completeAuthentication(
        previousUserId: 'u1',
        wasAnonymous: true,
        newUserId: 'u1',
        authProvider: 'apple',
        preservedUserId: true,
      );
      expect(refreshes, [('anonymous_upgrade_saved', true)]);
    });

    test('a refresh that throws does not fail the sign-in', () async {
      service = AuthMigrationService(
        userRepository: repo,
        database: _MockDatabase(),
        supabase: _MockSupabase()..stub(auth),
        report: report,
        refreshStartupSnapshot: (_) async => throw StateError('disposed'),
      );

      await freshLogin();

      expect(saved, isNotNull);
      verify(
        () => report.breadcrumb(
          'Startup snapshot refresh after sign-in save failed',
          category: 'startup',
          data: any(named: 'data'),
        ),
      ).called(1);
    });
  });
}

extension on _MockSupabase {
  void stub(GoTrueClient auth) => when(() => this.auth).thenReturn(auth);
}
