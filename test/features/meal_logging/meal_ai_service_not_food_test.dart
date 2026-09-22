/// Meal logging when the photo or the description is not food (mp-473, ticket
/// ai-cost 08): `describe-meal` and `analyze-meal-photo` answer 422
/// `{error:'not_food'}` and no macros at all.
///
/// The server sends a code, never prose. The one short line the athlete reads
/// comes from the content system, and nothing is invented: before this the text
/// function was told to return a placeholder item with guessed macros.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../meal_planning/helpers/fakes.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockStorage extends Mock implements SupabaseStorageClient {}

class _MockBucket extends Mock implements StorageFileApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });

  final content = loadDefaultContent();
  final expectedLine = content[ContentKeys.mpAnalysisNotFood]!;

  ContentService contentService() {
    final container = ProviderContainer(
      overrides: [contentServiceProvider.overrideWith(testContentService)],
    );
    addTearDown(container.dispose);
    return container.read(contentServiceProvider);
  }

  /// A service whose function call answers with [response], or throws [thrown].
  MealAiService service({FunctionResponse? response, Object? thrown}) {
    final supabase = supabaseWithSession();
    final functions = _MockFunctions();
    when(() => supabase.functions).thenReturn(functions);
    if (thrown != null) {
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenThrow(thrown);
    } else {
      when(
        () => functions.invoke(any(), body: any(named: 'body')),
      ).thenAnswer((_) async => response!);
    }
    // The photo path uploads before it analyzes; the upload succeeds.
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
    return MealAiService(supabase: supabase, content: contentService());
  }

  test('the content system carries a line for it', () {
    expect(expectedLine.isNotEmpty, isTrue);
    expect(expectedLine.length, lessThan(120), reason: 'one short line');
  });

  test('a described meal that is not food → the content system\'s line', () {
    expect(
      service(
        response: FunctionResponse(
          status: 422,
          data: const {'error': 'not_food'},
        ),
      ).describeMeal('the shawshank redemption'),
      throwsA(
        isA<MealAiException>()
            .having((e) => e.kind, 'kind', MealAiFailureKind.notFood)
            .having((e) => e.userMessage, 'userMessage', expectedLine),
      ),
    );
  });

  test('a photo that is not food → the same line', () {
    expect(
      service(
        response: FunctionResponse(
          status: 422,
          data: const {'error': 'not_food'},
        ),
      ).analyzePhotoBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<MealAiException>()
            .having((e) => e.kind, 'kind', MealAiFailureKind.notFood)
            .having((e) => e.userMessage, 'userMessage', expectedLine),
      ),
    );
  });

  test('the same when the client raises it as a FunctionException', () {
    expect(
      service(
        thrown: FunctionException(
          status: 422,
          details: const {'error': 'not_food'},
        ),
      ).describeMeal('a blue sky'),
      throwsA(
        isA<MealAiException>()
            .having((e) => e.kind, 'kind', MealAiFailureKind.notFood)
            .having((e) => e.userMessage, 'userMessage', expectedLine),
      ),
    );
  });

  test('the server\'s code never reaches the athlete', () {
    expect(
      service(
        response: FunctionResponse(
          status: 422,
          data: const {'error': 'not_food'},
        ),
      ).describeMeal('a movie title'),
      throwsA(
        isA<MealAiException>().having(
          (e) => e.userMessage,
          'userMessage',
          isNot(contains('not_food')),
        ),
      ),
    );
  });

  test('not food is never the top-up sheet — nothing was bought', () {
    expect(
      service(
        response: FunctionResponse(
          status: 422,
          data: const {'error': 'not_food'},
        ),
      ).describeMeal('a movie title'),
      throwsA(isNot(isA<InsufficientCreditsException>())),
    );
  });
}
