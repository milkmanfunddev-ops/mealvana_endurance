/// Content type for education items
enum EducationContentType {
  free,
  pro,
  course;

  static EducationContentType fromString(String value) {
    return EducationContentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EducationContentType.free,
    );
  }
}

/// Domain model for education content (videos, courses)
class EducationContent {
  const EducationContent({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.videoUrl,
    required this.contentType,
    this.durationSeconds,
    required this.sortOrder,
    required this.isPublished,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? videoUrl;
  final EducationContentType contentType;
  final int? durationSeconds;
  final int sortOrder;
  final bool isPublished;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Normalized display title for user-facing UI labels.
  /// Converts legacy variants like "ME101" or "ME 101" to "Mealvana 101".
  String get displayTitle => title.replaceAll(
    RegExp(r'\bME\s*101\b', caseSensitive: false),
    'Mealvana 101',
  );

  /// Format duration as "M:SS" (e.g., "5:30")
  String get formattedDuration {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory EducationContent.fromJson(Map<String, dynamic> json) {
    return EducationContent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      videoUrl: json['video_url'] as String?,
      contentType: EducationContentType.fromString(
        json['content_type'] as String? ?? 'free',
      ),
      durationSeconds: json['duration_seconds'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Grouped education content for display
class EducationContentGroups {
  const EducationContentGroups({
    this.freeVideos = const [],
    this.proVideos = const [],
    this.courses = const [],
  });

  final List<EducationContent> freeVideos;
  final List<EducationContent> proVideos;
  final List<EducationContent> courses;
}
