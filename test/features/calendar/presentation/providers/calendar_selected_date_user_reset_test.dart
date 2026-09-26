// Seam test through the real notifier (Finding 117-010): the selected day is
// per signed-in user. A sign-out, a sign-in and a new account all start on
// today; the same user re-emitted by the auth stream keeps the day.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/supabase_auth_service.dart'
    as supabase_auth;
import 'package:mealvana_endurance/features/auth/domain/auth_user.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_selected_date_provider.dart';

AuthUser _user(String id) =>
    AuthUser(id: id, email: '$id@example.com', isEmailConfirmed: true);

void main() {
  late StreamController<AuthUser?> auth;
  late ProviderContainer container;

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  setUp(() {
    auth = StreamController<AuthUser?>.broadcast();
    container = ProviderContainer(
      overrides: [
        supabase_auth.currentUserProvider.overrideWith((ref) => auth.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.close);
  });

  Future<void> emit(AuthUser? user) async {
    auth.add(user);
    await Future<void>.delayed(Duration.zero);
  }

  final sep20 = DateTime(2026, 9, 20);

  test('a sign-in after a sign-out opens on today', () async {
    container.listen(calendarSelectedDateProvider, (_, __) {});
    await emit(_user('test'));
    container.read(calendarSelectedDateProvider.notifier).setDate(sep20);
    expect(container.read(calendarSelectedDateProvider), sep20);

    await emit(null); // sign out
    expect(container.read(calendarSelectedDateProvider), today());

    container.read(calendarSelectedDateProvider.notifier).setDate(sep20);
    await emit(_user('test')); // sign in again
    expect(container.read(calendarSelectedDateProvider), today());
  });

  test('a different account never inherits the last viewed day', () async {
    container.listen(calendarSelectedDateProvider, (_, __) {});
    await emit(_user('test'));
    container.read(calendarSelectedDateProvider.notifier).setDate(sep20);

    await emit(_user('new-account'));
    expect(container.read(calendarSelectedDateProvider), today());
  });

  test('the same user re-emitted (token refresh) keeps the day', () async {
    container.listen(calendarSelectedDateProvider, (_, __) {});
    await emit(_user('test'));
    container.read(calendarSelectedDateProvider.notifier).setDate(sep20);

    await emit(_user('test'));
    expect(container.read(calendarSelectedDateProvider), sep20);
  });
}
