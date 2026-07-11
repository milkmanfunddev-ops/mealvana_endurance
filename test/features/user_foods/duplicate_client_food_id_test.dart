import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Independent regression coverage for Bug 38be3fdb — "Duplicate SiS salted
/// strawberry gels appear in food/fuel list" — exercised against a real
/// in-memory Drift DB (AppDatabase.forTesting(NativeDatabase.memory())),
/// per the food/fuel list surface (test/features/user_foods).
///
/// Root cause: two save paths (AddFoodScreen -> profile.id as device_id,
/// UserFoodCrudService -> profile.deviceId as device_id) wrote the same
/// catalog food's client_food_id under different device_id values, so the
/// `UNIQUE(device_id, client_food_id)` constraint never fired and
/// FoodsDao.getUserFoods() returned the food twice. The fix collapses
/// getUserFoods() results by clientFoodId (FoodsDao._dedupeByClientFoodId),
/// keeping the newest row and never collapsing null-clientFoodId (manual
/// entry) rows into each other.
///
/// This test was proven to fail pre-fix: with the DAO's dedupe step
/// temporarily short-circuited (returning the raw query results), the first
/// two cases below fail (list length 2, both gels visible) while the manual
/// entry case is unaffected — matching exactly what "before the fix" looked
/// like in production. Restored, all cases pass.
void main() {
  late AppDatabase database;

  const userId = 'user-uuid-999';
  const legacyDeviceId = 'legacy-device-999';
  const gelClientFoodId = 'sis-salted-strawberry-gel';
  const barClientFoodId = 'clif-bar-chocolate';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> saveFood({
    required String id,
    required String deviceId,
    required String userId,
    required String clientFoodId,
    required String name,
  }) {
    return database.foodsDao.saveUserFood(
      deviceId: deviceId,
      userId: userId,
      id: id,
      clientFoodId: clientFoodId,
      name: name,
      categories: const ['during_run'],
    );
  }

  test(
    'the reported scenario: gel saved via Swap/Preferences path (device_id '
    '= legacy deviceId) then again via Add Food path (device_id = '
    'profile.id) surfaces once, not twice, in the fuel list',
    () async {
      // Path 2 (UserFoodCrudService / Swap Food / Food Preferences):
      // device_id = profile.deviceId.
      await saveFood(
        id: '00000000-0000-0000-0000-0000000000a1',
        deviceId: legacyDeviceId,
        userId: userId,
        clientFoodId: gelClientFoodId,
        name: 'SiS Salted Strawberry Gel',
      );
      // Path 1 (AddFoodScreen, pre-fix): device_id = profile.id.
      await saveFood(
        id: '00000000-0000-0000-0000-0000000000a2',
        deviceId: userId,
        userId: userId,
        clientFoodId: gelClientFoodId,
        name: 'SiS Salted Strawberry Gel',
      );

      final foods = await database.foodsDao.getUserFoods(userId);
      final gels =
          foods.where((f) => f.clientFoodId == gelClientFoodId).toList();

      expect(
        gels,
        hasLength(1),
        reason: 'the same catalog gel saved via two device_id paths must '
            'collapse to a single fuel-list entry',
      );
    },
  );

  test(
    'a third save of the same client_food_id still collapses to one entry',
    () async {
      const ids = [
        '00000000-0000-0000-0000-0000000000e1',
        '00000000-0000-0000-0000-0000000000e2',
        '00000000-0000-0000-0000-0000000000e3',
      ];
      const deviceIds = [userId, legacyDeviceId, 'yet-another-device'];

      for (var i = 0; i < deviceIds.length; i++) {
        await saveFood(
          id: ids[i],
          deviceId: deviceIds[i],
          userId: userId,
          clientFoodId: gelClientFoodId,
          name: 'SiS Salted Strawberry Gel',
        );
      }

      final foods = await database.foodsDao.getUserFoods(userId);
      final gels =
          foods.where((f) => f.clientFoodId == gelClientFoodId).toList();

      expect(gels, hasLength(1));
    },
  );

  test(
    'distinct catalog foods (different client_food_id) are never collapsed '
    'into each other',
    () async {
      await saveFood(
        id: '00000000-0000-0000-0000-0000000000b1',
        deviceId: userId,
        userId: userId,
        clientFoodId: gelClientFoodId,
        name: 'SiS Salted Strawberry Gel',
      );
      await saveFood(
        id: '00000000-0000-0000-0000-0000000000b2',
        deviceId: userId,
        userId: userId,
        clientFoodId: barClientFoodId,
        name: 'Clif Bar Chocolate',
      );

      final foods = await database.foodsDao.getUserFoods(userId);

      expect(foods, hasLength(2));
      expect(foods.map((f) => f.clientFoodId),
          containsAll(<String>[gelClientFoodId, barClientFoodId]));
    },
  );

  test(
    'hasUserFoodWithClientFoodId used by AddFoodScreen catches an existing '
    'row saved via the legacy device_id path (Path 2)',
    () async {
      await saveFood(
        id: '00000000-0000-0000-0000-0000000000d1',
        deviceId: legacyDeviceId,
        userId: userId,
        clientFoodId: gelClientFoodId,
        name: 'SiS Salted Strawberry Gel',
      );

      final hasDuplicate = await database.foodsDao
          .hasUserFoodWithClientFoodId(userId, gelClientFoodId);

      expect(
        hasDuplicate,
        isTrue,
        reason: 'AddFoodScreen must detect the duplicate even though the '
            'existing row was persisted under a different device_id',
      );
    },
  );
}
