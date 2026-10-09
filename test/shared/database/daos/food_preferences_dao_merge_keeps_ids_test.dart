// develop-2026-10 ticket 78 (Finding 68-001): a merge save updates an
// existing (user_id, food_name) row in place. insertOrReplace answered the
// UNIQUE conflict by deleting the row and inserting a new one, so every save
// and every pull gave each food a new id and created_at.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

const _user = '607f9dd5-1c2b-4e3d-8f4a-5b6c7d8e9f01';
const _id = 'f410fe6a-37c5-4efd-ac84-7cd145db900f';
final _t0 = DateTime.utc(2026, 10, 8, 17, 23, 53);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: _id,
            userId: _user,
            foodName: 'sports_drink',
            preference: 'like',
            preferenceLevel: const Value(4),
            createdAt: Value(_t0),
            updatedAt: Value(_t0),
          ),
        );
  });

  tearDown(() => db.close());

  Future<List<FoodPreferenceEntry>> rows() =>
      db.foodPreferencesDao.getAllFoodPreferenceEntries(_user);

  test('a merge save at a new level keeps the id and created_at, changes the '
      'level and moves updated_at', () async {
    await db.foodPreferencesDao.saveFoodPreferences(
      _user,
      {'sports_drink': FoodPreference.like},
      sliderLevels: {'sports_drink': 3},
      mergeMode: true,
    );

    final row = (await rows()).single;
    expect(row.id, _id);
    expect(row.createdAt.isAtSameMomentAs(_t0), isTrue);
    expect(row.preferenceLevel, 3);
    expect(row.updatedAt.isAfter(_t0), isTrue);
  });

  test(
    'a merge save of a new food inserts one row and leaves the other',
    () async {
      await db.foodPreferencesDao.saveFoodPreferences(
        _user,
        {'granola_bar': FoodPreference.like},
        sliderLevels: {'granola_bar': 3},
        mergeMode: true,
        sources: {'granola_bar': 'allergy:gluten'},
      );

      final all = await rows();
      expect(all, hasLength(2));
      final drink = all.singleWhere((r) => r.foodName == 'sports_drink');
      expect(drink.id, _id);
      expect(drink.preferenceLevel, 4);
      final granola = all.singleWhere((r) => r.foodName == 'granola_bar');
      expect(granola.id, isNot(_id));
      expect(granola.preferenceSource, 'allergy:gluten');
    },
  );

  test('a replace save deletes every row, then inserts', () async {
    await db.foodPreferencesDao.saveFoodPreferences(_user, {
      'banana': FoodPreference.like,
    });

    final all = await rows();
    expect(all.map((r) => r.foodName), ['banana']);
    expect(all.single.id, isNot(_id));
  });
}
