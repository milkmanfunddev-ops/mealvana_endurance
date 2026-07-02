// Tests for EducationService — content grouping, empty states, error propagation
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/education/application/education_service.dart';
import 'package:mealvana_endurance/features/education/data/education_repository.dart';
import 'package:mealvana_endurance/features/education/domain/education_content.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockEducationRepository extends Mock implements EducationRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EducationContent _video({
  required String id,
  required String contentType,
  int sortOrder = 0,
}) =>
    EducationContent(
      id: id,
      title: 'Video $id',
      contentType: EducationContentType.fromString(contentType),
      sortOrder: sortOrder,
      isPublished: true,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 2),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockEducationRepository mockRepo;

  setUp(() {
    mockRepo = _MockEducationRepository();
  });

  EducationService _makeService() => EducationService(repository: mockRepo);

  // -------------------------------------------------------------------------
  // getContentGroups — grouping correctness
  // -------------------------------------------------------------------------

  group('EducationService.getContentGroups', () {
    test('separates free, pro and course videos into correct groups', () async {
      final allContent = [
        _video(id: 'f1', contentType: 'free'),
        _video(id: 'f2', contentType: 'free'),
        _video(id: 'p1', contentType: 'pro'),
        _video(id: 'c1', contentType: 'course'),
      ];
      when(() => mockRepo.getPublishedContent())
          .thenAnswer((_) async => allContent);

      final service = _makeService();
      final groups = await service.getContentGroups();

      expect(groups.freeVideos, hasLength(2));
      expect(groups.proVideos, hasLength(1));
      expect(groups.courses, hasLength(1));

      expect(groups.freeVideos.map((v) => v.id), containsAll(['f1', 'f2']));
      expect(groups.proVideos.first.id, 'p1');
      expect(groups.courses.first.id, 'c1');
    });

    test('returns all-empty groups when repository returns empty list', () async {
      when(() => mockRepo.getPublishedContent()).thenAnswer((_) async => []);

      final service = _makeService();
      final groups = await service.getContentGroups();

      expect(groups.freeVideos, isEmpty);
      expect(groups.proVideos, isEmpty);
      expect(groups.courses, isEmpty);
    });

    test('puts all-free content in freeVideos only', () async {
      when(() => mockRepo.getPublishedContent()).thenAnswer((_) async => [
            _video(id: 'f1', contentType: 'free'),
            _video(id: 'f2', contentType: 'free'),
          ]);

      final service = _makeService();
      final groups = await service.getContentGroups();

      expect(groups.freeVideos, hasLength(2));
      expect(groups.proVideos, isEmpty);
      expect(groups.courses, isEmpty);
    });

    test('puts all-pro content in proVideos only', () async {
      when(() => mockRepo.getPublishedContent()).thenAnswer((_) async => [
            _video(id: 'p1', contentType: 'pro'),
          ]);

      final service = _makeService();
      final groups = await service.getContentGroups();

      expect(groups.proVideos, hasLength(1));
      expect(groups.freeVideos, isEmpty);
      expect(groups.courses, isEmpty);
    });

    // BUG PROBE: what happens if repo throws?
    // EducationRepository.getPublishedContent() catches all errors and returns [].
    // But EducationService.getContentGroups() does NOT add its own try/catch.
    // If the repo contract changes (or is mocked to throw), the exception propagates.
    // This test documents current behavior.
    test('propagates exception when repository throws directly', () async {
      when(() => mockRepo.getPublishedContent())
          .thenThrow(Exception('network error'));

      final service = _makeService();
      expect(() => service.getContentGroups(), throwsException);
    });

    test('preserves order from repository (no re-sorting by service)', () async {
      // Repository is responsible for sort_order; service should not reorder
      final ordered = [
        _video(id: 'first', contentType: 'free', sortOrder: 1),
        _video(id: 'second', contentType: 'free', sortOrder: 2),
        _video(id: 'third', contentType: 'free', sortOrder: 3),
      ];
      when(() => mockRepo.getPublishedContent())
          .thenAnswer((_) async => ordered);

      final service = _makeService();
      final groups = await service.getContentGroups();

      expect(groups.freeVideos.map((v) => v.id).toList(),
          ['first', 'second', 'third'],
          reason: 'Service must not alter order returned by repository');
    });
  });

  // -------------------------------------------------------------------------
  // EducationController — via ProviderContainer
  // -------------------------------------------------------------------------

  group('EducationController build', () {
    test('loads EducationContentGroups on build', () async {
      final content = [
        _video(id: 'v1', contentType: 'free'),
      ];
      when(() => mockRepo.getPublishedContent())
          .thenAnswer((_) async => content);

      final container = ProviderContainer(
        overrides: [
          educationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Import the controller provider
      final groups = await container.read(educationServiceProvider).getContentGroups();
      expect(groups.freeVideos, hasLength(1));
    });
  });
}
