/// [UserFoodCrudService]'s immediate uploads send `user_foods` timestamptz
/// columns in UTC (develop-2026-10 ticket 39). A naive local string carried
/// no offset, so Postgres stored the wall clock as if it were UTC.
///
/// Seam: the real service against an in-memory Drift database and
/// [FakePostgrest]; each fire-and-forget upload is awaited by polling the
/// recorded writes.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/food_management/user_food_crud_service.dart';

import '../../../helpers/fakes/fake_postgrest.dart';
import '../../../helpers/fakes/recording_report.dart';

void main() {
  late AppDatabase database;
  late FakePostgrest server;
  late UserFoodCrudService service;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    server = FakePostgrest();
    service = UserFoodCrudService(database, RecordingReport(), server.client);
  });

  Future<Map<String, dynamic>> nextWrite(int count) async {
    for (var i = 0; i < 200 && server.writes.length < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(server.writes, hasLength(count));
    final body = server.writes.last.body;
    return ((body is List ? body.single : body) as Map).cast<String, dynamic>();
  }

  void expectUtcBetween(
    Map<String, dynamic> sent,
    List<String> keys,
    DateTime before,
  ) {
    final after = DateTime.now();
    for (final key in keys) {
      final value = sent[key] as String;
      expect(value, endsWith('Z'), reason: '$key carries its offset');
      final at = DateTime.parse(value);
      expect(at.isBefore(before), isFalse, reason: key);
      expect(at.isAfter(after), isFalse, reason: key);
    }
  }

  test('save, update and delete each send their timestamps in UTC', () async {
    var before = DateTime.now();
    await service.saveUserFood(
      Food(id: 'client-food-39', name: 'Rice cake'),
      const [],
    );
    final created = await nextWrite(1);
    expect(server.writes.last.table, 'user_foods');
    expectUtcBetween(created, [
      'created_at',
      'updated_at',
      'client_updated_at',
    ], before);
    final foodId = created['id'] as String;

    before = DateTime.now();
    expect(
      await service.updateUserFood(foodId: foodId, name: 'Rice cakes'),
      isTrue,
    );
    expectUtcBetween(await nextWrite(2), [
      'updated_at',
      'client_updated_at',
    ], before);

    before = DateTime.now();
    await service.deleteUserFood(foodId);
    expectUtcBetween(await nextWrite(3), ['updated_at'], before);
  });
}
