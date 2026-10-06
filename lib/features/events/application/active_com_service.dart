import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/report/report.dart';
import '../domain/active_com_event.dart';

part 'active_com_service.g.dart';

/// Active.com event search service provider
@riverpod
ActiveComService activeComService(Ref ref) {
  return ActiveComService(
    supabase: Supabase.instance.client,
    report: ref.watch(reportProvider),
  );
}

/// Service for searching endurance sports events via Active.com API
/// Provides autocomplete functionality for event creation
class ActiveComService {
  final SupabaseClient supabase;
  final Report report;

  ActiveComService({required this.supabase, required this.report});

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
    report.degraded(
      LoggedFault(
        'searchEvents called but active.com search is deprecated. Use searchPublicEvents instead.',
        context: 'ACTIVE_COM_SERVICE',
      ),
      area: 'events',
    );
    return [];
  }
}
