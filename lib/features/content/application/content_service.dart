import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/content_repository.dart';
import '../domain/app_content.dart';
import '../../../shared/services/report/report.dart';

/// Application service for managing app content
/// Follows the Andrea Bizzotto pattern with Ref for dependency injection
class ContentService {
  ContentService(this.ref);
  final Ref ref;

  // In-memory cache for lightning-fast access after initialization
  AppContent? _cachedContent;

  /// Get the content repository
  ContentRepository get _contentRepository =>
      ref.read(contentRepositoryProvider);

  /// Initialize content service - loads initial content and checks for updates
  Future<void> initialize() async {
    unawaited(ContentDefaultsCache.preload());
    // Load content into memory cache immediately (from cache or defaults)
    _cachedContent = await _contentRepository.getActiveContent();

    // Check for updates from Supabase in background
    _checkForUpdatesInBackground();
  }

  /// Check for updates in background without blocking the UI
  void _checkForUpdatesInBackground() {
    // Don't await this - let it run in background.
    //
    // The try/catch is not redundant with the .catchError below: it covers a
    // repository that throws SYNCHRONOUSLY, before any Future exists to
    // attach a handler to. Because initialize() is never awaited (the
    // provider kicks it on create), such a throw becomes an unhandled zone
    // error with no owner — it surfaces against whatever unrelated test or
    // frame happens to be running.
    try {
      _contentRepository
          .refreshContent()
          .then((latestContent) {
            // Update in-memory cache with refreshed content
            _cachedContent = latestContent;
          })
          .catchError((Object error, StackTrace stackTrace) {
            // The app continues on cached/default content.
            ref
                .read(reportProvider)
                .fault(
                  error,
                  stackTrace: stackTrace,
                  area: 'content',
                  message: 'Background content refresh failed',
                );
          });
    } catch (e, stackTrace) {
      // Same policy as the async path: the app continues on cached/default
      // content.
      ref
          .read(reportProvider)
          .fault(
            e,
            stackTrace: stackTrace,
            area: 'content',
            message: 'Background content refresh threw synchronously',
          );
    }
  }

  /// Get a content value by key with fallback (lightning-fast from memory).
  /// Precedence: active content (cache/remote) → bundled defaults →
  /// [defaultValue] → the raw key (last resort, and a bug signal).
  String getValue(String key, {String? defaultValue}) {
    return _cachedContent?.getValue(key) ??
        ContentDefaultsCache.values?[key] ??
        defaultValue ??
        key;
  }

  /// Refresh content from backend (Supabase) - for manual refresh
  Future<bool> refreshFromBackend() async {
    try {
      final refreshedContent = await _contentRepository.refreshContent();
      _cachedContent = refreshedContent;
      return true;
    } catch (e, stackTrace) {
      ref
          .read(reportProvider)
          .fault(
            e,
            stackTrace: stackTrace,
            area: 'content',
            message: 'Manual content refresh failed',
          );
      return false;
    }
  }

  /// Get the current active content object (lightning-fast from memory)
  AppContent? getActiveContent() {
    return _cachedContent;
  }

  /// Force refresh content (for testing or manual refresh)
  Future<void> forceRefresh() async {
    final freshContent = await _contentRepository.refreshContent();
    _cachedContent = freshContent;
  }

  /// Clear cached content (for debugging)
  Future<void> clearCache() async {
    await _contentRepository.clearCache();
    _cachedContent = null;
  }
}

/// Bundled-defaults cache, preloadable before the first frame.
///
/// `main()` awaits [preload] so every first-frame widget already sees real
/// values — a widget that reads a content key in its one synchronous build
/// (tab strips, headers) never re-renders on its own and would otherwise
/// show the raw key until something else rebuilt it.
///
/// Restored on develop-next 2026-10-08 (testing-wave ticket 40, Findings
/// 30-001/31-001/32-001): the branch split dropped commit 07dbca24's content
/// half, so every key-only lookup showed its key.
class ContentDefaultsCache {
  ContentDefaultsCache._();

  static Map<String, String>? _values;

  /// Flattened `content_defaults.json` values, or null before [preload].
  static Map<String, String>? get values => _values;

  static Future<void> preload() async {
    if (_values != null) return;
    try {
      final raw = await rootBundle.loadString(
        'assets/config/content_defaults.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final flat = <String, String>{};
      void walk(Map<String, dynamic> node, String prefix) {
        for (final entry in node.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            walk(value, key);
          } else if (value is String) {
            flat[key] = value;
          }
        }
      }

      walk(decoded, '');
      _values = flat;
    } catch (e, stackTrace) {
      // A missing/corrupt bundled asset is a build problem, not a runtime
      // one; getValue falls back to per-call defaults and the raw key.
      //
      // Catch-all, not `on Exception`: rootBundle throws a FlutterError (an
      // Error, not an Exception) when the asset is absent or the binding is
      // not initialized. Since initialize() leaves this future UNAWAITED,
      // anything that escapes here surfaces as an unhandled zone error with
      // no owner. D9: the silence is written down (this is a static class
      // with no ref, so the global Report carries it).
      await SentryReport.global.degraded(
        e,
        stackTrace: stackTrace,
        area: 'content',
        message: 'Bundled content defaults could not be loaded',
      );
    }
  }

  /// Test seam: forget the preloaded values.
  static void debugReset() => _values = null;
}

/// Provider for ContentService
final contentServiceProvider = Provider<ContentService>((ref) {
  final service = ContentService(ref);
  // Nothing else in startup awaits initialize(); start it here so every
  // consumer gets real values (cache → bundled defaults) without a caller
  // having to remember. main() has already preloaded the bundled defaults.
  unawaited(service.initialize());
  return service;
});
