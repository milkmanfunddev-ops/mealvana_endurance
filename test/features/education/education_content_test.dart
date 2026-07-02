// Tests for EducationContent domain model and EducationService grouping logic
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/education/domain/education_content.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EducationContent _makeContent({
  String id = 'video-1',
  String title = 'Test Video',
  String contentType = 'free',
  int? durationSeconds,
  int sortOrder = 0,
  bool isPublished = true,
  List<String> tags = const [],
}) =>
    EducationContent(
      id: id,
      title: title,
      contentType: EducationContentType.fromString(contentType),
      durationSeconds: durationSeconds,
      sortOrder: sortOrder,
      isPublished: isPublished,
      tags: tags,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // EducationContentType.fromString
  // -------------------------------------------------------------------------

  group('EducationContentType.fromString', () {
    test('parses "free" correctly', () {
      expect(EducationContentType.fromString('free'), EducationContentType.free);
    });

    test('parses "pro" correctly', () {
      expect(EducationContentType.fromString('pro'), EducationContentType.pro);
    });

    test('parses "course" correctly', () {
      expect(EducationContentType.fromString('course'), EducationContentType.course);
    });

    // BUG PROBE: unknown value should fall back to `free` per orElse clause
    test('falls back to free for unknown content type string', () {
      expect(EducationContentType.fromString('UNKNOWN'), EducationContentType.free);
    });

    test('falls back to free for empty string', () {
      expect(EducationContentType.fromString(''), EducationContentType.free);
    });

    // BUG PROBE: case sensitivity — "Free" (capital F) is NOT "free"
    // fromString uses `e.name == value` which is case-sensitive.
    // This documents current (case-sensitive) behavior.
    test('is case-sensitive — "Free" does not match "free" and falls back', () {
      expect(EducationContentType.fromString('Free'), EducationContentType.free,
          reason: 'Falls back to free because orElse fires on case mismatch');
    });
  });

  // -------------------------------------------------------------------------
  // EducationContent.displayTitle
  // -------------------------------------------------------------------------

  group('EducationContent.displayTitle', () {
    test('leaves unrelated titles unchanged', () {
      final c = _makeContent(title: 'Introduction to Sports Nutrition');
      expect(c.displayTitle, 'Introduction to Sports Nutrition');
    });

    test('replaces "ME101" with "Mealvana 101"', () {
      final c = _makeContent(title: 'ME101 Overview');
      expect(c.displayTitle, 'Mealvana 101 Overview');
    });

    test('replaces "ME 101" (with space) with "Mealvana 101"', () {
      final c = _makeContent(title: 'ME 101 Overview');
      expect(c.displayTitle, 'Mealvana 101 Overview');
    });

    test('replacement is case-insensitive — "me101" is replaced', () {
      final c = _makeContent(title: 'me101 course');
      expect(c.displayTitle, 'Mealvana 101 course');
    });

    test('does not replace "ME102" (different number)', () {
      final c = _makeContent(title: 'ME102 Advanced');
      expect(c.displayTitle, 'ME102 Advanced');
    });

    test('replaces multiple occurrences in a title', () {
      final c = _makeContent(title: 'ME101 and ME 101');
      expect(c.displayTitle, 'Mealvana 101 and Mealvana 101');
    });

    test('title that is exactly "ME101" becomes exactly "Mealvana 101"', () {
      final c = _makeContent(title: 'ME101');
      expect(c.displayTitle, 'Mealvana 101');
    });
  });

  // -------------------------------------------------------------------------
  // EducationContent.formattedDuration
  // -------------------------------------------------------------------------

  group('EducationContent.formattedDuration', () {
    test('returns empty string when durationSeconds is null', () {
      final c = _makeContent(durationSeconds: null);
      expect(c.formattedDuration, '');
    });

    test('formats exactly 0 seconds', () {
      final c = _makeContent(durationSeconds: 0);
      expect(c.formattedDuration, '0:00');
    });

    test('formats 60 seconds as "1:00"', () {
      final c = _makeContent(durationSeconds: 60);
      expect(c.formattedDuration, '1:00');
    });

    test('formats 90 seconds as "1:30"', () {
      final c = _makeContent(durationSeconds: 90);
      expect(c.formattedDuration, '1:30');
    });

    test('pads single-digit seconds with leading zero', () {
      final c = _makeContent(durationSeconds: 65);
      expect(c.formattedDuration, '1:05');
    });

    test('formats 3600 seconds (1 hour) as "60:00"', () {
      final c = _makeContent(durationSeconds: 3600);
      expect(c.formattedDuration, '60:00');
    });

    test('formats 330 seconds (5:30) correctly', () {
      final c = _makeContent(durationSeconds: 330);
      expect(c.formattedDuration, '5:30');
    });

    // BUG PROBE: does NOT format as H:MM:SS — just minutes and seconds.
    // 1 hour 5 minutes 3 seconds = 3903 seconds → "65:03" not "1:05:03"
    test('formats 3903 seconds as "65:03" (no hours segment)', () {
      final c = _makeContent(durationSeconds: 3903);
      expect(c.formattedDuration, '65:03');
    });
  });

  // -------------------------------------------------------------------------
  // EducationContent.fromJson
  // -------------------------------------------------------------------------

  group('EducationContent.fromJson', () {
    test('parses all required fields', () {
      final json = {
        'id': 'abc-123',
        'title': 'Nutrition Basics',
        'content_type': 'free',
        'sort_order': 1,
        'is_published': true,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-02T00:00:00.000Z',
      };
      final c = EducationContent.fromJson(json);

      expect(c.id, 'abc-123');
      expect(c.title, 'Nutrition Basics');
      expect(c.contentType, EducationContentType.free);
      expect(c.sortOrder, 1);
      expect(c.isPublished, isTrue);
    });

    test('applies defaults when optional fields are missing', () {
      final json = {
        'id': 'x',
        'title': 'Y',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final c = EducationContent.fromJson(json);

      expect(c.contentType, EducationContentType.free); // default
      expect(c.sortOrder, 0); // default
      expect(c.isPublished, isFalse); // default
      expect(c.tags, isEmpty); // default
      expect(c.durationSeconds, isNull);
      expect(c.description, isNull);
    });

    test('parses tags list correctly', () {
      final json = {
        'id': 'x',
        'title': 'Y',
        'tags': ['nutrition', 'running'],
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final c = EducationContent.fromJson(json);
      expect(c.tags, ['nutrition', 'running']);
    });

    test('handles null tags field (defaults to empty list)', () {
      final json = {
        'id': 'x',
        'title': 'Y',
        'tags': null,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final c = EducationContent.fromJson(json);
      expect(c.tags, isEmpty);
    });

    test('parses "pro" content type', () {
      final json = {
        'id': 'x',
        'title': 'Y',
        'content_type': 'pro',
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-01T00:00:00.000Z',
      };
      final c = EducationContent.fromJson(json);
      expect(c.contentType, EducationContentType.pro);
    });
  });

  // -------------------------------------------------------------------------
  // EducationContentGroups
  // -------------------------------------------------------------------------

  group('EducationContentGroups', () {
    test('constructs with empty lists by default', () {
      const groups = EducationContentGroups();
      expect(groups.freeVideos, isEmpty);
      expect(groups.proVideos, isEmpty);
      expect(groups.courses, isEmpty);
    });

    test('holds assigned lists correctly', () {
      final free = [_makeContent(id: 'f1', contentType: 'free')];
      final pro = [_makeContent(id: 'p1', contentType: 'pro')];
      final courses = [_makeContent(id: 'c1', contentType: 'course')];

      final groups = EducationContentGroups(
        freeVideos: free,
        proVideos: pro,
        courses: courses,
      );

      expect(groups.freeVideos, hasLength(1));
      expect(groups.proVideos, hasLength(1));
      expect(groups.courses, hasLength(1));
    });
  });
}
