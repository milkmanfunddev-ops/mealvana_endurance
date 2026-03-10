import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/education_repository.dart';
import '../domain/education_content.dart';

part 'education_service.g.dart';

@riverpod
EducationService educationService(Ref ref) {
  return EducationService(
    repository: ref.read(educationRepositoryProvider),
  );
}

/// Service for education content business logic
class EducationService {
  const EducationService({
    required EducationRepository repository,
  }) : _repository = repository;

  final EducationRepository _repository;

  /// Fetch content and group by type
  Future<EducationContentGroups> getContentGroups() async {
    final content = await _repository.getPublishedContent();

    return EducationContentGroups(
      freeVideos: content
          .where((c) => c.contentType == EducationContentType.free)
          .toList(),
      proVideos: content
          .where((c) => c.contentType == EducationContentType.pro)
          .toList(),
      courses: content
          .where((c) => c.contentType == EducationContentType.course)
          .toList(),
    );
  }
}
