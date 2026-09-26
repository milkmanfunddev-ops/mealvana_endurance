/// mp-672: the meal type of a described or photographed meal comes from the
/// time it was eaten. The app sends that clock as `eaten_at`, local-naive
/// `yyyy-MM-ddTHH:mm`; the server (`_shared/meal_analysis/slot_from_time.ts`)
/// picks the type from it.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../meal_planning/helpers/fakes.dart';

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockBucket extends Mock implements StorageFileApi {}

const _meal = {
  'name': 'Oats',
  'suggested_slot': 'breakfast',
  'confidence': 'high',
  'items': [
    {
      'name': 'Oats',
      'portion': '1 bowl',
      'calories': 350,
      'carb_g': 60.0,
      'protein_g': 12.0,
      'fat_g': 6.0,
      'sodium_mg': 10.0,
    },
  ],
  'totals': {
    'calories': 350,
    'carb_g': 60.0,
    'protein_g': 12.0,
    'fat_g': 6.0,
    'sodium_mg': 10.0,
  },
};

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  late _MockFunctions functions;
  late MealAiService service;

  setUp(() {
    final supabase = supabaseWithSession();
    functions = _MockFunctions();
    when(() => supabase.functions).thenReturn(functions);
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => FunctionResponse(status: 200, data: _meal));
    final storage = _MockStorage();
    final bucket = _MockBucket();
    when(() => supabase.storage).thenReturn(storage);
    when(() => storage.from(any())).thenReturn(bucket);
    when(
      () => bucket.uploadBinary(
        any(),
        any(),
        fileOptions: any(named: 'fileOptions'),
      ),
    ).thenAnswer((_) async => 'ok');
    service = MealAiService(supabase: supabase);
  });

  Map<String, dynamic> sentBody(String fn) =>
      verify(
            () => functions.invoke(fn, body: captureAny(named: 'body')),
          ).captured.single
          as Map<String, dynamic>;

  test('the wire form is the local wall clock with no offset', () {
    expect(
      mealAiEatenAtWire(DateTime(2026, 9, 4, 7, 5, 59)),
      '2026-09-04T07:05',
    );
    expect(
      mealAiEatenAtWire(DateTime.utc(2026, 9, 24, 15, 18)),
      '2026-09-24T15:18',
    );
  });

  test('describe-meal carries eaten_at', () async {
    await service.describeMeal(
      'a bowl of oats',
      eatenAt: DateTime(2026, 9, 24, 11),
    );
    expect(sentBody('describe-meal')['eaten_at'], '2026-09-24T11:00');
  });

  test('analyze-meal-photo carries eaten_at, now when none is given', () async {
    await service.analyzePhotoBytes(Uint8List.fromList([1, 2, 3]));
    final sent = sentBody('analyze-meal-photo')['eaten_at'] as String;
    expect(sent, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$')));
  });
}
