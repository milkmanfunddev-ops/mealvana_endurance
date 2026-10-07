/// `UserDao.getLocalUserProfile` (ticket 102): the signed-in account's
/// profile only. It used to return the latest-updated profile of any account
/// on the phone, which named the wrong athlete in analytics.
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    // B's profile is the newer one.
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: _a,
            deviceId: 'device',
            authUserId: const Value(_a),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: _b,
            deviceId: 'device',
            authUserId: const Value(_b),
            updatedAt: Value(DateTime(2026, 9, 1)),
          ),
        );
  });

  test("returns the signed-in account's profile, not the newest", () async {
    final profile = await db.userDao.getLocalUserProfile(_a);
    expect(profile?.id, _a);
  });

  test('returns null with no session', () async {
    expect(await db.userDao.getLocalUserProfile(null), isNull);
  });

  test('finds a legacy profile by its row id', () async {
    const legacy = 'device-profile-0000-4000-8000-000000000009';
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(id: legacy, deviceId: 'device'),
        );
    final profile = await db.userDao.getLocalUserProfile(legacy);
    expect(profile?.id, legacy);
  });
}
