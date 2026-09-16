/// Regression — sport preferences persist through the REAL UserDao.
///
/// Before the 2026-09-11 v20 fix the local `users` table had no columns for
/// any of these: `saveUserProfile`/`updateUserProfile` silently dropped all
/// eight fields, so "Cycling details updated" never survived a reopen
/// (Stage E sim walk; ops bug
/// 2026-09-11-sport-prefs-ftp-css-never-persist-locally). This pins the full
/// save → read-back loop the settings screens actually use.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fixtures/user_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('all eight sport-preference fields survive save → read-back', () async {
    final profile = UserFixtures.completedUser(id: 'u-sport').copyWith(
      ftpWatts: 250,
      cssPacePer100mSeconds: 95,
      giSensitivity: true,
      typicalBikeBottles: 3,
      hasAeroBottle: true,
      hasBentoBox: false,
      typicalWetsuit: true,
      typicalSwimCapType: 'silicone',
    );

    await db.userDao.saveUserProfile(profile);
    final loaded = await db.userDao.getUserProfileById('u-sport');

    expect(loaded!.ftpWatts, 250);
    expect(loaded.cssPacePer100mSeconds, 95);
    expect(loaded.giSensitivity, isTrue);
    expect(loaded.typicalBikeBottles, 3);
    expect(loaded.hasAeroBottle, isTrue);
    expect(loaded.hasBentoBox, isFalse);
    expect(loaded.typicalWetsuit, isTrue);
    expect(loaded.typicalSwimCapType, 'silicone');
  });

  test('updateUserProfile round-trips a changed FTP — the settings save path',
      () async {
    await db.userDao.saveUserProfile(
      UserFixtures.completedUser(id: 'u-sport').copyWith(ftpWatts: 200),
    );

    final current = await db.userDao.getUserProfileById('u-sport');
    await db.userDao.updateUserProfile(current!.copyWith(ftpWatts: 250));

    final reloaded = await db.userDao.getUserProfileById('u-sport');
    expect(reloaded!.ftpWatts, 250,
        reason: 'the exact loop the sim walk saw fail: save 250, reopen, 0');
  });

  test('unset fields stay null — never fabricated', () async {
    await db.userDao.saveUserProfile(UserFixtures.completedUser(id: 'u-null'));
    final loaded = await db.userDao.getUserProfileById('u-null');
    expect(loaded!.ftpWatts, isNull);
    expect(loaded.cssPacePer100mSeconds, isNull);
    expect(loaded.typicalSwimCapType, isNull);
  });
}
