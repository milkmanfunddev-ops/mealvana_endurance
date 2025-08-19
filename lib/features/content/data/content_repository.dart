import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/app_content.dart';

part 'content_repository.g.dart';

/// Repository for managing app content with local caching and remote syncing
class ContentRepository {
  ContentRepository({
    required this.contentBox,
    required this.supabase,
  });
  
  static const String boxName = 'contentcontentBox';
  static const String _defaultsAssetPath = 'assets/config/content_defaults.json';
  static const String supabaseTableName = 'app_content';
  
  final Box<AppContent> contentBox;
  final SupabaseClient supabase;

  /// Get the current active content
  Future<AppContent?> getActiveContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    // First try to get from local cache
    final cached = contentBox.values
        .where((content) => 
            content.environment == environment && 
            content.locale == locale && 
            content.isActive)
        .cast<AppContent?>()
        .firstOrNull;

    if (cached != null) {
      return cached;
    }

    // If no cached content, load defaults
    return await _loadDefaultContent();
  }

  /// Check for updates from Supabase in background
  Future<AppContent?> checkForUpdates({
    String environment = 'production',
    String locale = 'en',
  }) async {
    try {
      // Get current cached version
      final currentContent = await getActiveContent(
        environment: environment,
        locale: locale,
      );
      final currentVersion = currentContent?.version ?? 0;

      // Check Supabase for latest version
      final latestContent = await fetchLatestContent(
        environment: environment,
        locale: locale,
      );

      // If we found a newer version, it's already saved by fetchLatestContent
      if (latestContent != null && latestContent.version > currentVersion) {
        print('Content updated to version ${latestContent.version}');
        return latestContent;
      }
    } catch (e) {
      print('Background content update failed (using cached/defaults): $e');
      // Don't throw - app should continue with cached/default content
    }
    return null;
  }

  /// Load default content from assets
  Future<AppContent> _loadDefaultContent() async {
    try {
      final jsonString = await rootBundle.loadString(_defaultsAssetPath);
      final jsonData = json.decode(jsonString);
      
      final defaultContent = AppContent.fromJson({
        'version': 1,
        'environment': 'production',
        'locale': 'en',
        'content': jsonData,
        'last_updated': DateTime.now().toIso8601String(),
        'is_active': true,
      });

      // Cache the defaults locally
      await _saveContent(defaultContent);
      return defaultContent;
    } catch (e) {
      // If asset loading fails, return minimal fallback
      return AppContent(
        version: 1,
        environment: 'production',
        locale: 'en',
        content: _getMinimalFallbackContent(),
        lastUpdated: DateTime.now(),
        isActive: true,
      );
    }
  }

  /// Fetch latest content from Supabase
  Future<AppContent?> fetchLatestContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
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
        // Convert Supabase response to AppContent
        final supabaseContent = Map<String, dynamic>.from(response);
        
        // Map Supabase fields to our model
        final content = AppContent.fromJson({
          'version': supabaseContent['version'],
          'environment': supabaseContent['environment'],
          'locale': supabaseContent['locale'],
          'content': supabaseContent['content'],
          'last_updated': supabaseContent['updated_at'], // Note: Supabase uses 'updated_at'
          'is_active': supabaseContent['is_active'],
        });
        
        await _saveContent(content);
        return content;
      }
    } catch (e) {
      // Failed to fetch from backend, continue with cached content
      print('Failed to fetch content from Supabase: $e');
    }
    return null;
  }

  /// Save content to local cache
  Future<void> _saveContent(AppContent content) async {
    final key = '${content.environment}_${content.locale}';
    
    // Deactivate any existing content for this environment/locale
    for (final existing in contentBox.values) {
      if (existing.environment == content.environment && 
          existing.locale == content.locale && 
          existing.isActive) {
        final updated = existing.copyWith(isActive: false);
        final existingKey = contentBox.keys
            .firstWhere((k) => contentBox.get(k) == existing, orElse: () => null);
        if (existingKey != null) {
          await contentBox.put(existingKey, updated);
        }
      }
    }

    // Save new active content
    await contentBox.put(key, content);
  }

  /// Get a specific content value by key
  Future<String> getValue(
    String key, {
    String? defaultValue,
    String environment = 'production',
    String locale = 'en',
  }) async {
    final content = await getActiveContent(
      environment: environment, 
      locale: locale,
    );
    
    return content?.getValue(key, defaultValue: defaultValue) ?? 
           defaultValue ?? 
           key;
  }

  /// Check if we should refresh content (e.g., daily)
  bool shouldRefreshContent() {
    final activeContent = contentBox.values
        .where((content) => content.isActive)
        .cast<AppContent?>()
        .firstOrNull;

    if (activeContent == null) return true;

    final hoursSinceUpdate = DateTime.now()
        .difference(activeContent.lastUpdated)
        .inHours;

    return hoursSinceUpdate > 24; // Refresh daily
  }

  /// Get minimal fallback content for critical app functionality
  Map<String, dynamic> _getMinimalFallbackContent() {
    return {
      'main_screen': {
        'title': 'Mealvana Endurance',
        'generate_button': 'Generate Plan',
      },
      'plan_screen': {
        'title': 'Plan',
        'save_button': 'Save',
        'saved_button': 'Saved',
      },
      'error': {
        'generic': 'Something went wrong. Please try again.',
        'network': 'Network error. Please check your connection.',
      },
    };
  }

  /// Clear all cached content (for testing/debugging)
  Future<void> clearCache() async {
    await contentBox.clear();
  }
}

/// Content box provider
@Riverpod(keepAlive: true)
Future<Box<AppContent>> contentBox(Ref ref) async {
  return await Hive.openBox<AppContent>(ContentRepository.boxName);
}

/// Repository provider following Andrea's pattern
@riverpod
ContentRepository contentRepository(Ref ref) {
  return ContentRepository(
    contentBox: ref.watch(contentBoxProvider).requireValue,
    supabase: Supabase.instance.client,
  );
}