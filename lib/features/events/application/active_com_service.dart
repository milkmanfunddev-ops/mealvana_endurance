import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/active_com_event.dart';

part 'active_com_service.g.dart';

/// Active.com event search service provider
@riverpod
ActiveComService activeComService(Ref ref) {
  return ActiveComService(
    supabase: Supabase.instance.client,
    logger: ref.watch(appLoggerProvider),
  );
}

/// Service for searching endurance sports events via Active.com API
/// Provides autocomplete functionality for event creation
class ActiveComService {
  final SupabaseClient supabase;
  final AppLogger logger;

  ActiveComService({required this.supabase, required this.logger});

  /// Search for events by keyword
  ///
  /// Returns a list of matching events from Active.com
  /// Returns empty list on error (graceful fallback to manual entry)
  ///
  /// Example:
  /// ```dart
  /// final events = await service.searchEvents('Boston Marathon');
  /// ```
  Future<List<ActiveComEvent>> searchEvents(String query) async {
    // Deprecated - this functionality has been removed
    logger.warning(
      'searchEvents called but active.com search is deprecated. Use searchPublicEvents instead.',
      context: 'ACTIVE_COM_SERVICE',
    );
    return [];
  }
}
