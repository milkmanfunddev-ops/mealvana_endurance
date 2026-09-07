import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/content_repository.dart';
import '../domain/app_content.dart';

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
    // Load content into memory cache immediately (from cache or defaults)
    _cachedContent = await _contentRepository.getActiveContent();
    unawaited(ContentDefaultsCache.preload());

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
          .catchError((error) {
            // Silently handle errors - app continues with cached/default
            // content. Log error but don't print in production.
          });
    } catch (_) {
      // Same policy as the async path: the app continues on cached/default
      // content.
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
    } catch (e) {
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
    } catch (_) {
      // A missing/corrupt bundled asset is a build problem, not a runtime
      // one; getValue falls back to per-call defaults and the raw key.
      //
      // Catch-all, not `on Exception`: rootBundle throws a FlutterError (an
      // Error, not an Exception) when the asset is absent or the binding is
      // not initialized. Since initialize() leaves this future UNAWAITED,
      // anything that escapes here surfaces as an unhandled zone error with
      // no owner — which is exactly how it showed up, as eleven unrelated
      // ContentService tests failing with "Binding has not yet been
      // initialized".
    }
  }
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
