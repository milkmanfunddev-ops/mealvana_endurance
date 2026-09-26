// Finding 117-008 (ticket 141): Learn offline said "No videos available yet"
// because the repository swallowed a failed fetch into an empty list. It now
// keeps the last good rows on the device and falls back to them; with no
// last answer it throws, so the screen can say the connection is the trouble.
//
// Seam: the cache holds rows as the server sent them (snake_case JSON),
// never the repository's own parsed output.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/education/data/education_cache.dart';
import 'package:mealvana_endurance/features/education/data/education_repository.dart';

import '../../helpers/widget_test_harness.dart';

class _MockSupabase extends Mock implements SupabaseClient {}

/// A row as PostgREST returns it.
Map<String, dynamic> _row(String id, {String type = 'free'}) => {
  'id': id,
  'title': 'Lesson $id',
  'description': null,
  'thumbnail_url': null,
  'video_url': 'https://videos.test/$id.mp4',
  'content_type': type,
  'duration_seconds': 90,
  'sort_order': 1,
  'is_published': true,
  'tags': <String>[],
  'created_at': '2026-09-01T00:00:00Z',
  'updated_at': '2026-09-02T00:00:00Z',
};

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  EducationRepository repo(Future<List<dynamic>> Function() fetch) =>
      EducationRepository(
        supabase: _MockSupabase(),
        logger: MockAppLogger(),
        cache: EducationCache(prefs),
        fetchRows: fetch,
      );

  test('a good fetch is parsed and kept as the server sent it', () async {
    final rows = [_row('a'), _row('b', type: 'pro')];
    final content = await repo(() async => rows).getPublishedContent();

    expect(content.map((c) => c.id), ['a', 'b']);
    expect(EducationCache(prefs).read(), rows);
  });

  test('a failed fetch falls back to the last good rows', () async {
    await EducationCache(prefs).write([_row('cached')]);

    final content = await repo(
      () async => throw const SocketExceptionLike(),
    ).getPublishedContent();

    expect(content.map((c) => c.id), ['cached']);
    expect(content.single.title, 'Lesson cached');
  });

  test('a failed fetch with nothing cached throws, not an empty list', () {
    expect(
      repo(() async => throw const SocketExceptionLike()).getPublishedContent(),
      throwsA(isA<EducationUnavailableException>()),
    );
  });

  test('a good fetch after a failure replaces the cache', () async {
    await EducationCache(prefs).write([_row('old')]);

    await repo(() async => [_row('new')]).getPublishedContent();

    expect(EducationCache(prefs).read()!.single['id'], 'new');
  });

  test('an unreadable cache reads as no cache', () async {
    await prefs.setString(EducationCache.key, '{not json');
    expect(EducationCache(prefs).read(), isNull);
  });
}

/// Stands in for the plugin's network failure ("Network is unreachable").
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
