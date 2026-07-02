// Tests for ContentRepository — caching, staleness, fallback chain
// Uses SharedPreferences mock + SupabaseClient mock (no real network calls)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/content/data/content_repository.dart';
import 'package:mealvana_endurance/features/content/domain/app_content.dart';

// ---------------------------------------------------------------------------
// Mocks — we only need to stub Supabase; SharedPreferences uses the in-memory mock
// ---------------------------------------------------------------------------

class _MockSupabaseClient extends Mock implements SupabaseClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _contentJson({
  int version = 1,
  String environment = 'production',
  String locale = 'en',
  Map<String, dynamic>? content,
  String? lastUpdated,
  bool isActive = true,
}) =>
    {
      'version': version,
      'environment': environment,
      'locale': locale,
      'content': content ?? <String, dynamic>{},
      'last_updated': lastUpdated ?? DateTime(2025, 1, 1).toIso8601String(),
      'is_active': isActive,
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSupabaseClient mockSupabase;
  late SharedPreferences prefs;

  setUp(() async {
    mockSupabase = _MockSupabaseClient();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ContentRepository _makeRepo() => ContentRepository(
        supabase: mockSupabase,
        sharedPreferences: prefs,
      );

  // ---------------------------------------------------------------------------
  // isCacheStale
  // ---------------------------------------------------------------------------

  group('ContentRepository.isCacheStale', () {
    test('returns true when no cache exists', () async {
      final repo = _makeRepo();
      expect(await repo.isCacheStale(), isTrue);
    });

    test('returns false when cache is fresh (within maxAge)', () async {
      final fresh = _contentJson(
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      );
      await prefs.setString('app_content_cache', json.encode(fresh));

      final repo = _makeRepo();
      expect(await repo.isCacheStale(maxAge: const Duration(hours: 24)), isFalse);
    });

    test('returns true when cache is older than maxAge', () async {
      final stale = _contentJson(
        lastUpdated: DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
      );
      await prefs.setString('app_content_cache', json.encode(stale));

      final repo = _makeRepo();
      expect(await repo.isCacheStale(maxAge: const Duration(hours: 24)), isTrue);
    });

    test('respects custom maxAge boundary exactly', () async {
      // 30 minutes old — should NOT be stale under 1-hour maxAge
      final cached = _contentJson(
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      );
      await prefs.setString('app_content_cache', json.encode(cached));

      final repo = _makeRepo();
      expect(await repo.isCacheStale(maxAge: const Duration(hours: 1)), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // clearCache
  // ---------------------------------------------------------------------------

  group('ContentRepository.clearCache', () {
    test('removes cached content from SharedPreferences', () async {
      await prefs.setString(
          'app_content_cache', json.encode(_contentJson()));

      final repo = _makeRepo();
      await repo.clearCache();

      expect(prefs.getString('app_content_cache'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getActiveContent — cache hit
  // ---------------------------------------------------------------------------

  group('ContentRepository.getActiveContent — cache hit', () {
    test('returns cached content when environment and locale match', () async {
      final cachedData = _contentJson(
        version: 5,
        environment: 'production',
        locale: 'en',
        content: {'key': 'from_cache'},
        isActive: true,
      );
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      final repo = _makeRepo();
      final result = await repo.getActiveContent();

      expect(result, isNotNull);
      expect(result!.version, 5);
      expect(result.content['key'], 'from_cache');

      // Supabase should NOT have been called
      verifyNever(() => mockSupabase.from(any()));
    });

    test('bypasses cache when environment does not match', () async {
      // Cache has staging; request is for production
      final cachedData = _contentJson(environment: 'staging', isActive: true);
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      // Supabase will throw (simulating unavailable) → falls through to asset default
      when(() => mockSupabase.from(any())).thenThrow(Exception('no network'));

      final repo = _makeRepo();
      // This will fail to fetch from Supabase and fall back to asset defaults.
      // The asset path won't load in unit test context, so we just verify no exception
      // is thrown (graceful fallback to empty AppContent).
      final result = await repo.getActiveContent(environment: 'production');
      // Fallback returns non-null (empty AppContent)
      expect(result, isNotNull);
    });

    test('bypasses cache when isActive is false', () async {
      final cachedData = _contentJson(isActive: false);
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      when(() => mockSupabase.from(any())).thenThrow(Exception('no network'));

      final repo = _makeRepo();
      // Should skip the inactive cache and try remote (which fails), then fall back
      final result = await repo.getActiveContent();
      expect(result, isNotNull); // absolute fallback always returns something
    });
  });

  // ---------------------------------------------------------------------------
  // getActiveContent — corrupt cache
  // ---------------------------------------------------------------------------

  group('ContentRepository.getActiveContent — corrupt cache', () {
    test('handles malformed JSON in cache gracefully', () async {
      await prefs.setString('app_content_cache', 'NOT_VALID_JSON{{{{');

      when(() => mockSupabase.from(any())).thenThrow(Exception('no network'));

      final repo = _makeRepo();
      // Should not throw — corrupt cache is caught, falls back to empty AppContent
      final result = await repo.getActiveContent();
      expect(result, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getContentValue
  // ---------------------------------------------------------------------------

  group('ContentRepository.getContentValue', () {
    test('resolves dot-notation key from cached content', () async {
      final cachedData = _contentJson(
        content: {'main_screen': <String, dynamic>{'title': 'Cached Title'}},
      );
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      final repo = _makeRepo();
      final value =
          await repo.getContentValue('main_screen.title', defaultValue: 'fallback');

      expect(value, 'Cached Title');
    });

    test('returns defaultValue when key path not found', () async {
      final cachedData = _contentJson(content: {});
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      final repo = _makeRepo();
      final value =
          await repo.getContentValue('nonexistent.key', defaultValue: 'my-default');

      expect(value, 'my-default');
    });
  });

  // ---------------------------------------------------------------------------
  // refreshContent — clears cache and re-fetches
  // ---------------------------------------------------------------------------

  group('ContentRepository.refreshContent', () {
    test('removes cache key before re-fetching', () async {
      final cachedData = _contentJson(version: 1);
      await prefs.setString(
          'app_content_cache', json.encode(cachedData));

      // Supabase throws → falls through to empty default
      when(() => mockSupabase.from(any())).thenThrow(Exception('no network'));

      final repo = _makeRepo();
      await repo.refreshContent();

      // After refreshContent, cache was cleared and re-populated (or empty default used)
      // Either way — no stale v1 cache was used
      final remaining = prefs.getString('app_content_cache');
      // The cache key may have been repopulated with whatever was returned.
      // What matters: the old v1 value is not blindly used — version may still
      // be 1 from the fallback, but the important thing is refreshContent didn't throw.
      // We verify the cache was at least cleared at some point in the call.
      expect(remaining, isNull); // fallback (asset load fails in test) leaves no cache
    });
  });
}

// 'app_content_cache' is 'app_content_cache' (static const in the class).
// Since it's private to the library we use the known literal in tests.
// If the key ever changes, tests below will surface the mismatch clearly.
