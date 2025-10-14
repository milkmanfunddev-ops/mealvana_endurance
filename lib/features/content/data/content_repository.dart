import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_content.dart';
import '../../../shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'content_repository.g.dart';

/// Repository for managing app content with local caching and remote syncing
/// Uses SharedPreferences for simple content caching instead of Drift database
class ContentRepository {
  ContentRepository({
    required this.supabase,
  });
  
  static const String _contentKey = 'app_content_cache';
  static const String _defaultsAssetPath = 'assets/config/content_defaults.json';
  static const String supabaseTableName = 'app_content';
  
  final SupabaseClient supabase;

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
    final remoteContent = await _fetchFromSupabase(environment, locale);
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
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_contentKey);
      
      if (cachedJson != null) {
        final Map<String, dynamic> contentMap = json.decode(cachedJson);
        return AppContent.fromJson(contentMap);
      }
    } catch (e) {
      DebugLogger.error('Error reading cached content: $e');
    }
    return null;
  }

  /// Cache content locally
  Future<void> _cacheContent(AppContent content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentJson = json.encode(content.toJson());
      await prefs.setString(_contentKey, contentJson);
    } catch (e) {
      DebugLogger.error('Error caching content: $e');
    }
  }

  /// Fetch content from Supabase
  Future<AppContent?> _fetchFromSupabase(String environment, String locale) async {
    try {
      final response = await supabase
          .from(supabaseTableName)
          .select()
          .eq('environment', environment)
          .eq('locale', locale)
          .eq('is_active', true)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AppContent.fromJson(response);
      }
    } catch (e) {
      DebugLogger.error('Error fetching content from Supabase: $e');
    }
    return null;
  }

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
    } catch (e) {
      DebugLogger.error('Error loading default content: $e');
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

  /// Force refresh content from remote
  Future<AppContent> refreshContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    // Clear local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contentKey);
    
    // Force fetch from remote
    final content = await getActiveContent(environment: environment, locale: locale);
    return content ?? await _loadDefaultContent();
  }

  /// Get specific content value by key path (dot notation)
  Future<String?> getContentValue(String keyPath, {String? defaultValue}) async {
    final content = await getActiveContent();
    return content?.getValue(keyPath, defaultValue: defaultValue) ?? defaultValue;
  }

  /// Check if cached content is stale (older than specified duration)
  Future<bool> isCacheStale({Duration maxAge = const Duration(hours: 24)}) async {
    final cachedContent = await _getCachedContent();
    if (cachedContent == null) return true;
    
    final age = DateTime.now().difference(cachedContent.lastUpdated);
    return age > maxAge;
  }

  /// Clear all cached content
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contentKey);
  }
}

/// Content repository provider
@riverpod
ContentRepository contentRepository(Ref ref) {
  final supabase = ref.read(appExternalDepsProvider).supabaseClient;
  return ContentRepository(
    supabase: supabase,
  );
}
