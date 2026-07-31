import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../domain/public_event.dart';

part 'public_events_service.g.dart';

/// Provider for PublicEventsService
@riverpod
PublicEventsService publicEventsService(Ref ref) {
  return PublicEventsService(supabaseClient: ref.watch(supabaseClientProvider));
}

/// Service for searching public events
///
/// Calls the search-public-events Edge Function to search the public_events table.
class PublicEventsService {
  final SupabaseClient _supabase;

  PublicEventsService({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  /// Search for public events
  ///
  /// Calls the search-public-events Edge Function with the following parameters:
  /// - [query]: Search query (min 2 characters)
  /// - [limit]: Maximum number of results (default: 10)
  /// - [eventType]: Optional filter by event type (e.g., 'running', 'cycling')
  /// - [state]: Optional filter by state (e.g., 'california', 'alabama')
  ///
  /// Returns a list of PublicEvent objects matching the search criteria.
  Future<List<PublicEvent>> searchEvents({
    required String query,
    int limit = 10,
    String? eventType,
    String? state,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'search-public-events',
        body: {
          'query': query,
          'limit': limit,
          if (eventType != null) 'eventType': eventType,
          if (state != null) 'state': state,
        },
      );

      // Check for errors
      if (response.status != 200) {
        throw Exception('Failed to search events: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;
      final events = (data['events'] as List)
          .map((e) => PublicEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      return events;
    } catch (e) {
      // Log error and return empty list
      // TODO: Use AppLogger for proper error tracking
      return [];
    }
  }
}
