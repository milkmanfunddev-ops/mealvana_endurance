import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/prefs_provider.dart';
import '../domain/education_content.dart';
import 'education_cache.dart';

part 'education_repository.g.dart';

@riverpod
EducationRepository educationRepository(Ref ref) {
  return EducationRepository(
    supabase: Supabase.instance.client,
    logger: ref.read(appLoggerProvider),
    cache: EducationCache(ref.watch(sharedPreferencesProvider)),
  );
}

/// The education fetch failed and nothing was ever loaded on this device,
/// so there is no last answer to show. Learn shows its offline state with
/// Retry (testing-wave 117-008), never the "no videos" empty state, which
/// is for a good answer with nothing in it.
class EducationUnavailableException implements Exception {
  const EducationUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'EducationUnavailableException($cause)';
}

/// Repository for fetching education content from Supabase.
///
/// Server content, read-only, with one device cache of the last good
/// answer: a fetch that fails falls back to it, and one that fails with no
/// cache throws [EducationUnavailableException]. The fetch used to swallow
/// every failure into an empty list, which Learn showed as "No videos
/// available yet" while offline (117-008).
class EducationRepository {
  const EducationRepository({
    required SupabaseClient supabase,
    required AppLogger logger,
    EducationCache? cache,
    @visibleForTesting Future<List<dynamic>> Function()? fetchRows,
  }) : _supabase = supabase,
       _logger = logger,
       _cache = cache,
       _fetchRows = fetchRows;

  final SupabaseClient _supabase;
  final AppLogger _logger;
  final EducationCache? _cache;

  /// Tests stand in for the PostgREST query; the app leaves it null.
  final Future<List<dynamic>> Function()? _fetchRows;

  /// Fetch all published education content ordered by sort_order.
  ///
  /// Twice at once (a pull-to-refresh during the first load) runs two
  /// fetches and writes the cache twice with the same rows; the last write
  /// wins and both are the server's answer, so repeating is safe.
  Future<List<EducationContent>> getPublishedContent() async {
    List<dynamic> rows;
    try {
      rows = await (_fetchRows?.call() ?? _queryRows());
    } catch (e) {
      _logger.warning('Failed to fetch education content: $e');
      final cached = _cache?.read();
      if (cached == null) throw EducationUnavailableException(e);
      _logger.info(
        'Showing ${cached.length} cached education rows after a failed fetch',
      );
      return _parse(cached);
    }
    try {
      await _cache?.write(rows);
    } catch (e) {
      // A cache that will not write only costs the next offline visit.
      _logger.warning('Failed to cache education content: $e');
    }
    return _parse(rows);
  }

  Future<List<dynamic>> _queryRows() async {
    final response = await _supabase
        .from('education_content')
        .select()
        .eq('is_published', true)
        .order('sort_order', ascending: true);
    return response as List<dynamic>;
  }

  List<EducationContent> _parse(List<dynamic> rows) => rows
      .map((json) => EducationContent.fromJson(json as Map<String, dynamic>))
      .toList();
}
