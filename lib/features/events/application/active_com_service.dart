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

  ActiveComService({
    required this.supabase,
    required this.logger,
  });

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
    try {
      // Don't search if query is empty or too short
      if (query.trim().isEmpty || query.trim().length < 2) {
        return [];
      }

      logger.info(
        'Searching Active.com for events: "$query"',
        context: 'ACTIVE_COM_SERVICE',
      );

      final response = await supabase.functions.invoke(
        'search-active-events',
        body: {
          'query': query.trim(),
        },
      );

      if (response.status != 200) {
        logger.warning(
          'Active.com API returned non-200 status: ${response.status}',
          context: 'ACTIVE_COM_SERVICE',
        );
        return [];
      }

      final data = response.data;
      if (data == null || data['success'] != true || data['events'] == null) {
        logger.warning(
          'Invalid response from Active.com API',
          context: 'ACTIVE_COM_SERVICE',
        );
        return [];
      }

      // Parse events from response
      final eventsList = data['events'] as List<dynamic>;
      final events = eventsList
          .map((json) {
            try {
              return ActiveComEvent.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              logger.error(
                'Error parsing Active.com event',
                error: e,
                context: 'ACTIVE_COM_SERVICE',
              );
              return null;
            }
          })
          .whereType<ActiveComEvent>()
          .toList();

      logger.info(
        'Found ${events.length} events from Active.com',
        context: 'ACTIVE_COM_SERVICE',
      );

      return events;
    } catch (e, stackTrace) {
      logger.error(
        'Error searching Active.com',
        error: e,
        stackTrace: stackTrace,
        context: 'ACTIVE_COM_SERVICE',
      );
      // Fail silently - return empty list to allow manual entry
      return [];
    }
  }
}
