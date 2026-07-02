// Tests for ContentService — getValue fallback logic, initialize, refresh
// ContentService takes Ref and uses ref.read(contentRepositoryProvider).
// We override contentRepositoryProvider in a ProviderContainer and retrieve
// the service via the contentServiceProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/data/content_repository.dart';
import 'package:mealvana_endurance/features/content/domain/app_content.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockContentRepository extends Mock implements ContentRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppContent _content({
  Map<String, dynamic> content = const {},
  int version = 1,
  String environment = 'production',
  String locale = 'en',
}) =>
    AppContent(
      version: version,
      environment: environment,
      locale: locale,
      content: content,
      lastUpdated: DateTime(2025, 1, 1),
      isActive: true,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockContentRepository mockRepo;

  setUp(() {
    mockRepo = _MockContentRepository();
  });

  ProviderContainer _container() {
    final c = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ContentService _service(ProviderContainer container) =>
      container.read(contentServiceProvider);

  // ---------------------------------------------------------------------------
  // initialize + getActiveContent
  // ---------------------------------------------------------------------------

  group('ContentService.initialize', () {
    test('caches content returned by repository on first call', () async {
      final expected = _content(
          content: {'main_screen': <String, dynamic>{'title': 'Hello'}});

      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => expected);

      // refreshContent is called in background — stub it to avoid noise
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => expected);

      final c = _container();
      final service = _service(c);
      await service.initialize();

      expect(service.getActiveContent(), equals(expected));
    });

    test('getActiveContent returns null before initialize is called', () {
      final c = _container();
      final service = _service(c);
      expect(service.getActiveContent(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getValue — fallback chain
  // ---------------------------------------------------------------------------

  group('ContentService.getValue', () {
    test('returns value from cache when key exists', () async {
      final appContent = _content(content: {
        'main_screen': <String, dynamic>{'title': 'Run Fast'},
      });
      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);

      final c = _container();
      final service = _service(c);
      await service.initialize();

      expect(service.getValue('main_screen.title'), 'Run Fast');
    });

    test('returns provided defaultValue when key is missing from cache', () async {
      final appContent = _content(content: {});
      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);

      final c = _container();
      final service = _service(c);
      await service.initialize();

      expect(service.getValue('missing.key', defaultValue: 'my_fallback'),
          'my_fallback');
    });

    // When cache is null (before initialize), getValue falls through:
    //   _cachedContent?.getValue(...) = null
    //   → defaultValue ?? key
    // So: no default → returns the key itself as sentinel string.
    test('returns key string as sentinel when uninitialized and no default provided',
        () {
      final c = _container();
      final service = _service(c);
      expect(service.getValue('some.key'), 'some.key');
    });

    test('returns defaultValue when uninitialized and defaultValue is provided', () {
      final c = _container();
      final service = _service(c);
      expect(service.getValue('some.key', defaultValue: 'fb'), 'fb');
    });

    test('returns defaultValue when repo returns null (no cache, no remote)', () async {
      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => null);
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => _content());

      final c = _container();
      final service = _service(c);
      await service.initialize();

      // _cachedContent is null after init returns null → falls to defaultValue
      expect(service.getValue('any.key', defaultValue: 'safe'), 'safe');
    });
  });

  // ---------------------------------------------------------------------------
  // refreshFromBackend
  // ---------------------------------------------------------------------------

  group('ContentService.refreshFromBackend', () {
    test('returns true and updates cache on success', () async {
      final fresh = _content(content: {'updated': 'yes'}, version: 2);

      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => fresh);

      final c = _container();
      final service = _service(c);
      final result = await service.refreshFromBackend();

      expect(result, isTrue);
      expect(service.getActiveContent(), equals(fresh));
    });

    test('returns false when repository throws', () async {
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenThrow(Exception('network error'));

      final c = _container();
      final service = _service(c);
      final result = await service.refreshFromBackend();

      expect(result, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // clearCache
  // ---------------------------------------------------------------------------

  group('ContentService.clearCache', () {
    test('sets cached content to null and delegates to repository', () async {
      final appContent = _content(content: {'x': 'y'});
      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => appContent);
      when(() => mockRepo.clearCache()).thenAnswer((_) async {});

      final c = _container();
      final service = _service(c);
      await service.initialize();
      expect(service.getActiveContent(), isNotNull);

      await service.clearCache();

      expect(service.getActiveContent(), isNull);
      verify(() => mockRepo.clearCache()).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // forceRefresh
  // ---------------------------------------------------------------------------

  group('ContentService.forceRefresh', () {
    test('replaces cache with fresh content from repository', () async {
      final stale = _content(content: {'version': 'stale'}, version: 1);
      final fresh = _content(content: {'version': 'fresh'}, version: 2);

      // Initialize with stale
      when(() => mockRepo.getActiveContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => stale);
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => stale);

      final c = _container();
      final service = _service(c);
      await service.initialize();
      expect(service.getActiveContent()?.version, 1);

      // Now change the refresh stub to return fresh content
      when(() => mockRepo.refreshContent(
            environment: any(named: 'environment'),
            locale: any(named: 'locale'),
          )).thenAnswer((_) async => fresh);

      await service.forceRefresh();

      expect(service.getActiveContent()?.version, 2);
    });
  });
}
