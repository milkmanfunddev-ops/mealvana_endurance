import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/app_content.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';

part 'content_repository.g.dart';

/// Repository for managing app content with local caching and remote syncing
/// Uses SharedPreferences for simple content caching instead of Drift database
class ContentRepository {
  ContentRepository({
    required this.supabase,
    required this.sharedPreferences,
    Report? report,
    @visibleForTesting
    Future<Map<String, dynamic>?> Function(String environment, String locale)?
    fetchRow,
  }) : _reportOverride = report,
       _fetchRow = fetchRow;

  static const String _contentKey = 'app_content_cache';
  static const String _defaultsAssetPath =
      'assets/config/content_defaults.json';
  static const String supabaseTableName = 'app_content';

  final SupabaseClient supabase;
  final SharedPreferences sharedPreferences;
  final Report? _reportOverride;

  /// Tests stand in for the PostgREST query; the app leaves it null.
  final Future<Map<String, dynamic>?> Function(
    String environment,
    String locale,
  )?
  _fetchRow;

  Report get _report => _reportOverride ?? SentryReport.global;

  /// Get the current active content
  Future<AppContent?> getActiveContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    // First try to get from local cache
    final cachedContent = await _getCachedContent();

    if (cachedContent != null &&
        cachedContent.environment == environment &&
        cachedContent.locale == locale &&
        cachedContent.isActive) {
      return cachedContent;
    }

    // Try to fetch from Supabase
    final (:remoteContent, fetched: _) = await _fetchFromSupabase(
      environment,
      locale,
    );
    if (remoteContent != null) {
      await _cacheContent(remoteContent);
      return remoteContent;
    }

    // Fallback to local defaults
    return await _loadDefaultContent();
  }

  /// Get content from local cache
  Future<AppContent?> _getCachedContent() async {
    try {
      final cachedJson = sharedPreferences.getString(_contentKey);

      if (cachedJson != null) {
        final Map<String, dynamic> contentMap = json.decode(cachedJson);
        return AppContent.fromJson(contentMap);
      }
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'content',
        message: 'Error reading cached content',
      );
    }
    return null;
  }

  /// Cache content locally
  Future<void> _cacheContent(AppContent content) async {
    try {
      final contentJson = json.encode(content.toJson());
      await sharedPreferences.setString(_contentKey, contentJson);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'content',
        message: 'Error caching content',
      );
    }
  }

  /// Fetch content from Supabase. [fetched] is false when the fetch itself
  /// failed (offline, a server error), so [refreshContent] can keep the cache
  /// it has; true with a null [remoteContent] means the server has no active
  /// row.
  Future<({AppContent? remoteContent, bool fetched})> _fetchFromSupabase(
    String environment,
    String locale,
  ) async {
    try {
      final response =
          await (_fetchRow?.call(environment, locale) ??
              _queryRow(environment, locale));
      return (
        remoteContent: response == null ? null : AppContent.fromJson(response),
        fetched: true,
      );
    } catch (e, stackTrace) {
      // Offline at cold start is weather (ticket 55, 50-003): a
      // `content.weather` breadcrumb and one count; the app runs on the cache
      // or the bundled defaults. Runs before analytics starts, so the count
      // is a Sentry counter. Anything else faults.
      await _report.faultUnlessWeather(
        e,
        stackTrace: stackTrace,
        area: 'content',
        message: 'Error fetching content from Supabase',
      );
    }
    return (remoteContent: null, fetched: false);
  }

  Future<Map<String, dynamic>?> _queryRow(String environment, String locale) =>
      supabase
          .from(supabaseTableName)
          .select()
          .eq('environment', environment)
          .eq('locale', locale)
          .eq('is_active', true)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();

  /// Load default content from assets
  Future<AppContent> _loadDefaultContent() async {
    try {
      final String jsonString = await rootBundle.loadString(_defaultsAssetPath);
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      // Wrap the defaults in AppContent structure
      return AppContent(
        version: 1,
        environment: 'production',
        locale: 'en',
        content: jsonMap,
        lastUpdated: DateTime.now(),
        isActive: true,
      );
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'content',
        message: 'Error loading default content',
      );
      // Return empty content as absolute fallback
      return AppContent(
        version: 1,
        environment: 'production',
        locale: 'en',
        content: {},
        lastUpdated: DateTime.now(),
        isActive: true,
      );
    }
  }

  /// Force refresh content from remote.
  ///
  /// The cache is kept until a fetch succeeds (ticket 55, Lee 2026-10-08):
  /// deleting it first meant an offline launch threw away a good server copy
  /// and the next launches ran on bundled defaults until a fetch got through.
  /// A fetch that fails keeps the cache and answers with it (or the defaults
  /// when there is none); a fetch that succeeds replaces it, and one that
  /// finds no active row clears it, so content the server withdrew goes.
  Future<AppContent> refreshContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    final (:remoteContent, :fetched) = await _fetchFromSupabase(
      environment,
      locale,
    );
    if (remoteContent != null) {
      await _cacheContent(remoteContent);
      return remoteContent;
    }
    if (fetched) {
      await sharedPreferences.remove(_contentKey);
      _report.breadcrumb(
        'Content cache cleared: server has no active content',
        category: 'content',
        data: {'environment': environment, 'locale': locale},
      );
      return _loadDefaultContent();
    }

    final cached = await _getCachedContent();
    if (cached != null &&
        cached.environment == environment &&
        cached.locale == locale &&
        cached.isActive) {
      return cached;
    }
    return _loadDefaultContent();
  }

  /// Get specific content value by key path (dot notation)
  Future<String?> getContentValue(
    String keyPath, {
    String? defaultValue,
  }) async {
    final content = await getActiveContent();
    return content?.getValue(keyPath, defaultValue: defaultValue) ??
        defaultValue;
  }

  /// Check if cached content is stale (older than specified duration)
  Future<bool> isCacheStale({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final cachedContent = await _getCachedContent();
    if (cachedContent == null) return true;

    final age = DateTime.now().difference(cachedContent.lastUpdated);
    return age > maxAge;
  }

  /// Clear all cached content
  Future<void> clearCache() async {
    await sharedPreferences.remove(_contentKey);
  }
}

/// Content repository provider
@riverpod
ContentRepository contentRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return ContentRepository(
    supabase: deps.supabaseClient,
    sharedPreferences: deps.sharedPreferences,
    report: ref.read(reportProvider),
  );
}
