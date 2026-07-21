// Tests for AppContent domain model — getValue dot-notation, fromJson, copyWith, equality
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/domain/app_content.dart';

void main() {
  final _baseDate = DateTime(2025, 1, 1);

  AppContent _make({
    Map<String, dynamic> content = const {},
    int version = 1,
    String environment = 'production',
    String locale = 'en',
  }) => AppContent(
    version: version,
    environment: environment,
    locale: locale,
    content: content,
    lastUpdated: _baseDate,
    isActive: true,
  );

  // ---------------------------------------------------------------------------
  // getValue — dot-notation key resolution
  // ---------------------------------------------------------------------------

  group('AppContent.getValue — dot-notation', () {
    test('returns top-level string value', () {
      final c = _make(content: {'title': 'Hello'});
      expect(c.getValue('title'), 'Hello');
    });

    test('resolves one level of nesting', () {
      final c = _make(
        content: {
          'main_screen': {'title': 'Mealvana Endurance'},
        },
      );
      expect(c.getValue('main_screen.title'), 'Mealvana Endurance');
    });

    test('resolves two levels of nesting', () {
      final c = _make(
        content: {
          'adjust_macros': {
            'banner': {'short_run': 'Carbs optional'},
          },
        },
      );
      expect(c.getValue('adjust_macros.banner.short_run'), 'Carbs optional');
    });

    test('returns defaultValue when top-level key is absent', () {
      final c = _make(content: {});
      expect(c.getValue('missing_key', defaultValue: 'fallback'), 'fallback');
    });

    test('returns null when top-level key is absent and no defaultValue', () {
      final c = _make(content: {});
      expect(c.getValue('missing_key'), isNull);
    });

    test('returns defaultValue when intermediate key is absent', () {
      final c = _make(content: {'main_screen': <String, dynamic>{}});
      expect(
        c.getValue('main_screen.title', defaultValue: 'default'),
        'default',
      );
    });

    test('returns defaultValue when value is not a map at intermediate step', () {
      // 'main_screen' is a String, not a Map — traversal should bail gracefully
      final c = _make(content: {'main_screen': 'flat_string'});
      expect(
        c.getValue('main_screen.title', defaultValue: 'fallback'),
        'fallback',
      );
    });

    test('converts non-String leaf values to string', () {
      final c = _make(content: {'count': 42});
      expect(c.getValue('count'), '42');
    });

    test('returns null for null leaf values (no default)', () {
      final c = _make(content: {'key': null});
      expect(c.getValue('key'), isNull);
    });

    test('returns defaultValue for null leaf when default provided', () {
      final c = _make(content: {'key': null});
      expect(c.getValue('key', defaultValue: 'my-default'), 'my-default');
    });

    test('empty key string returns defaultValue', () {
      // An empty key splits to [''] which is a map lookup for '' — absent.
      final c = _make(content: {});
      expect(c.getValue('', defaultValue: 'fb'), 'fb');
    });
  });

  // ---------------------------------------------------------------------------
  // fromJson
  // ---------------------------------------------------------------------------

  group('AppContent.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'version': 3,
        'environment': 'staging',
        'locale': 'fr',
        'content': {'key': 'value'},
        'last_updated': '2024-06-01T12:00:00.000Z',
        'is_active': false,
      };
      final c = AppContent.fromJson(json);

      expect(c.version, 3);
      expect(c.environment, 'staging');
      expect(c.locale, 'fr');
      expect(c.content, {'key': 'value'});
      expect(c.isActive, isFalse);
    });

    test('applies defaults when optional fields are missing', () {
      final c = AppContent.fromJson({'content': {}});
      expect(c.version, 1);
      expect(c.environment, 'production');
      expect(c.locale, 'en');
      expect(c.isActive, isTrue);
    });

    test('handles missing content by defaulting to empty map', () {
      final c = AppContent.fromJson(<String, dynamic>{});
      expect(c.content, isEmpty);
    });

    test('roundtrips through toJson and back', () {
      final original = _make(
        content: {'a': 'b'},
        version: 5,
        environment: 'staging',
        locale: 'de',
      );
      final json = original.toJson();
      final restored = AppContent.fromJson(json);

      expect(restored.version, original.version);
      expect(restored.environment, original.environment);
      expect(restored.locale, original.locale);
      expect(restored.content, original.content);
      expect(restored.isActive, original.isActive);
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  group('AppContent.copyWith', () {
    test('returns new instance with updated field', () {
      final original = _make(version: 1);
      final updated = original.copyWith(version: 2);

      expect(updated.version, 2);
      expect(updated.environment, original.environment);
    });

    test('preserves all fields when no arguments given', () {
      final original = _make(content: {'x': 'y'});
      final copy = original.copyWith();

      expect(copy.version, original.version);
      expect(copy.content, original.content);
    });
  });

  // ---------------------------------------------------------------------------
  // equality
  // ---------------------------------------------------------------------------

  group('AppContent equality', () {
    test('two instances with same version/env/locale are equal', () {
      final a = _make(version: 1, environment: 'production', locale: 'en');
      final b = _make(version: 1, environment: 'production', locale: 'en');
      expect(a, equals(b));
    });

    test('different version makes instances unequal', () {
      final a = _make(version: 1);
      final b = _make(version: 2);
      expect(a, isNot(equals(b)));
    });

    test('different locale makes instances unequal', () {
      final a = _make(locale: 'en');
      final b = _make(locale: 'fr');
      expect(a, isNot(equals(b)));
    });

    test('identical instances share same hashCode', () {
      final a = _make(version: 1);
      final b = _make(version: 1);
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
