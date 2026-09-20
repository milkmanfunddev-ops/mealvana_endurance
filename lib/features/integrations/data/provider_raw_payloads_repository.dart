import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/logging_service.dart';

/// Uploads raw FS/TP provider payloads into `provider_raw_payloads`
/// (real-payload-corpus@v1; contract: qa lifecycle.md L-7, mirrored at
/// docs/ssot — raw retention, 90-day TTL, server-side).
///
/// Versioning contract (raw-retention vectors): one row per
/// (provider workout id, last_modified). A re-fetch with an unchanged
/// last_modified writes NOTHING — enforced by insert-or-ignore against the
/// table's full unique constraint. An edited workout (changed last_modified)
/// inserts a NEW row; history is never replaced.
///
/// This is a capture side-channel off the sync path: callers fire it
/// non-blocking, and it never throws — a capture failure must never fail or
/// slow a sync. Rows it fails to upload are simply re-offered on the next
/// sync pass (the same fetch re-produces them; dedup makes that free).
class ProviderRawPayloadsRepository {
  ProviderRawPayloadsRepository({
    required SupabaseClient supabase,
    AppLogger? logger,
  }) : _supabase = supabase,
       _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppLogger _logger;

  static const _table = 'provider_raw_payloads';

  /// The unique constraint's column list — a FULL unique constraint, so
  /// PostgREST on_conflict is safe (never a partial index; repo 42P10 rule).
  static const _conflictTarget =
      'user_id,provider,provider_workout_id,last_modified';

  /// Uploads one sync pass's raw payloads. [idOf] extracts the provider's
  /// workout id from a raw object; [lastModifiedOf] extracts the provider's
  /// last-modified value VERBATIM (identity token, never parsed as a date —
  /// provider timestamps are naive local wall-clock, lifecycle.md L-9).
  /// Objects with a missing/empty id are skipped: an unidentifiable payload
  /// has no versioning identity. A missing last-modified stores '' (one
  /// version per workout id).
  Future<void> uploadRawPayloads({
    required String userId,
    required String provider,
    required List<Map<String, dynamic>> payloads,
    required String? Function(Map<String, dynamic> payload) idOf,
    String? Function(Map<String, dynamic> payload)? lastModifiedOf,
  }) async {
    if (payloads.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (final payload in payloads) {
      final id = idOf(payload);
      if (id == null || id.isEmpty) continue;
      rows.add({
        'user_id': userId,
        'provider': provider,
        'provider_workout_id': id,
        'last_modified': lastModifiedOf?.call(payload) ?? '',
        'data': payload,
      });
    }
    if (rows.isEmpty) return;

    try {
      await _supabase
          .from(_table)
          .upsert(rows, onConflict: _conflictTarget, ignoreDuplicates: true);
      _logger.info(
        'Raw payload capture uploaded',
        context: 'RAW_PAYLOAD_CAPTURE',
        data: {'provider': provider, 'offered': rows.length},
      );
    } catch (e) {
      // Never rethrow: capture is a side-channel. The next sync re-offers the
      // same rows. (Deliberately NOT the silent-failure pattern of
      // uploadDirtyRecords — this logs with context every time.)
      _logger.warning(
        'Raw payload capture failed (will retry next sync): $e',
        context: 'RAW_PAYLOAD_CAPTURE',
        data: {'provider': provider, 'offered': rows.length},
      );
    }
  }
}
