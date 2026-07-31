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

    // Check for updates from Supabase in background
    _checkForUpdatesInBackground();
  }

  /// Check for updates in background without blocking the UI
  void _checkForUpdatesInBackground() {
    // Don't await this - let it run in background
    _contentRepository
        .refreshContent()
        .then((latestContent) {
          // Update in-memory cache with refreshed content
          _cachedContent = latestContent;
        })
        .catchError((error) {
          // Silently handle errors - app continues with cached/default content
          // Log error but don't print in production
        });
  }

  /// Get a content value by key with fallback (lightning-fast from memory)
  String getValue(String key, {String? defaultValue}) {
    return _cachedContent?.getValue(key, defaultValue: defaultValue) ??
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

/// Provider for ContentService
final contentServiceProvider = Provider<ContentService>((ref) {
  return ContentService(ref);
});
