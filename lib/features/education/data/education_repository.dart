import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/report/report.dart';
import '../domain/education_content.dart';

part 'education_repository.g.dart';

@riverpod
EducationRepository educationRepository(Ref ref) {
  return EducationRepository(
    supabase: Supabase.instance.client,
    report: ref.read(reportProvider),
  );
}

/// Repository for fetching education content from Supabase
/// Read-only (no local caching needed - server content only)
class EducationRepository {
  const EducationRepository({
    required SupabaseClient supabase,
    required Report report,
  }) : _supabase = supabase,
       _report = report;

  final SupabaseClient _supabase;
  final Report _report;

  /// Fetch all published education content ordered by sort_order
  Future<List<EducationContent>> getPublishedContent() async {
    try {
      final response = await _supabase
          .from('education_content')
          .select()
          .eq('is_published', true)
          .order('sort_order', ascending: true);

      return (response as List<dynamic>)
          .map(
            (json) => EducationContent.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e, stackTrace) {
      _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'education',
        message: 'Failed to fetch education content',
      );
      return [];
    }
  }
}
