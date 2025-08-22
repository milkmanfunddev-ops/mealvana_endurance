/// Model representing app content/copy stored locally
/// Removed Hive dependencies as part of migration to Drift database
class AppContent {
  final int version;
  final String environment;
  final String locale;
  final Map<String, dynamic> content;
  final DateTime lastUpdated;
  final bool isActive;

  AppContent({
    required this.version,
    required this.environment,
    required this.locale,
    required this.content,
    required this.lastUpdated,
    required this.isActive,
  });

  /// Create from JSON (e.g., from Supabase or local assets)
  factory AppContent.fromJson(Map<String, dynamic> json) {
    return AppContent(
      version: json['version'] ?? 1,
      environment: json['environment'] ?? 'production',
      locale: json['locale'] ?? 'en',
      content: Map<String, dynamic>.from(json['content'] ?? {}),
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'environment': environment,
      'locale': locale,
      'content': content,
      'last_updated': lastUpdated.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Get a nested value from content using dot notation
  /// e.g., getValue('main_screen.title')
  String? getValue(String key, {String? defaultValue}) {
    final parts = key.split('.');
    dynamic value = content;
    
    for (final part in parts) {
      if (value is Map) {
        value = value[part];
      } else {
        return defaultValue;
      }
    }
    
    return value?.toString() ?? defaultValue;
  }

  /// Create a copy with updated fields
  AppContent copyWith({
    int? version,
    String? environment,
    String? locale,
    Map<String, dynamic>? content,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return AppContent(
      version: version ?? this.version,
      environment: environment ?? this.environment,
      locale: locale ?? this.locale,
      content: content ?? this.content,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppContent &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          environment == other.environment &&
          locale == other.locale;

  @override
  int get hashCode => version.hashCode ^ environment.hashCode ^ locale.hashCode;
}