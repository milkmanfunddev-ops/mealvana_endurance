// Finding 117-008 (ticket 141): Learn offline said "No videos available yet"
// because the repository swallowed a failed fetch into an empty list. It now
// keeps the last good rows on the device and falls back to them; with no
// last answer it throws, so the screen can say the connection is the trouble.
//
// Seam: the cache holds rows as the server sent them (snake_case JSON),
// never the repository's own parsed output.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/education/data/education_cache.dart';
import 'package:mealvana_endurance/features/education/data/education_repository.dart';

import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';

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
        report: const NoopReport(),
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

  // develop-2026-10 ticket 55 (50-003): offline is weather, not a report.
  group('what a failed fetch reports', () {
    late RecordingReport report;

    EducationRepository recorded(Future<List<dynamic>> Function() fetch) =>
        EducationRepository(
          supabase: _MockSupabase(),
          report: report,
          cache: EducationCache(prefs),
          fetchRows: fetch,
        );

    setUp(() => report = RecordingReport());

    test('offline with a cache: the cached rows, one education.weather '
        'breadcrumb, one count, no fault or degraded', () async {
      await EducationCache(prefs).write([_row('cached')]);

      final content = await recorded(
        () async => throw const SocketException(
          'Failed host lookup',
          osError: OSError('nodename nor servname provided', 8),
        ),
      ).getPublishedContent();

      expect(content.single.id, 'cached');
      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
      expect(
        report.calls.where(
          (c) => c.severity == 'breadcrumb' && c.area == 'education.weather',
        ),
        hasLength(1),
      );
      expect(report.counts.single.message, expectedFailureEvent);
      expect(report.counts.single.tags, containsPair('area', 'education'));
    });

    test(
      'offline with no cache: the thrown exception is already reported',
      () async {
        Object? thrown;
        try {
          await recorded(
            () async => throw const SocketException('Network is unreachable'),
          ).getPublishedContent();
        } catch (e) {
          thrown = e;
        }

        expect(thrown, isA<EducationUnavailableException>());
        expect(SentryReport.wasReported(thrown!), isTrue);
        expect(report.faults, isEmpty);
      },
    );

    test('a server error still faults, with area education', () async {
      await EducationCache(prefs).write([_row('cached')]);

      await recorded(
        () async => throw const PostgrestException(
          message: 'permission denied',
          code: '42501',
        ),
      ).getPublishedContent();

      expect(report.faults, hasLength(1));
      expect(report.faults.single.area, 'education');
      expect(report.counts, isEmpty);
    });
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
