import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../domain/entitlement.dart';

part 'user_entitlements_repository.g.dart';

/// Reads its Supabase client from [appExternalDepsProvider] (the seam the
/// widget-test harness mocks) rather than `Supabase.instance`.
@riverpod
UserEntitlementsRepository userEntitlementsRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return UserEntitlementsRepository(
    supabase: deps.supabaseClient,
    database: ref.watch(appDatabaseProvider),
    report: ref.watch(reportProvider),
  );
}

/// Reads the signed-in user's `user_entitlements` rows — the server-side Pro
/// paywall the RevenueCat webhook maintains — and mirrors them into the Drift
/// `user_entitlements` table so the gate can be answered offline.
///
/// Read-only on both sides: RLS is owner-select / service_role-write, so
/// there is no upload path, no `needs_upload`, and this is deliberately NOT a
/// [SyncableRepository]. A failed remote read returns null and the caller
/// falls back to [readCached]; nothing here throws.
class UserEntitlementsRepository {
  UserEntitlementsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    Report? report,
  }) : _supabase = supabase,
       _database = database,
       _report = report;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final Report? _report;

  Report get _r => _report ?? SentryReport.global;

  static const _area = 'subscription';
  static const _table = 'user_entitlements';

  /// The signed-in user's id, or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Whether the session is a Supabase *anonymous* user. Purchases are refused
  /// for them for the same reason as credit packs: the webhook maps
  /// `app_user_id` onto `auth.users.id`, and signing in to an existing account
  /// later swaps the id and strands the subscription.
  bool get isAnonymousUser => _supabase.auth.currentUser?.isAnonymous ?? false;

  /// Auth identity as a stream (null on sign-out), distinct so token refreshes
  /// don't chatter — the rebuild signal for the status provider.
  Stream<String?> get authUserIdChanges => _supabase.auth.onAuthStateChange
      .map((s) => s.session?.user.id)
      .distinct();

  /// Mirror the 7-tap tester switch onto `users.is_internal` — the flag the
  /// server-side Pro gate (`has_entitlement`, the vana functions' `requirePro`)
  /// checks. Without this, a team member who flips the switch sees the Food
  /// tab (the client gate merges the tester grant) but every `vana-*` call
  /// 403s on prod, because the server has no idea the device is internal.
  ///
  /// RLS `users_update_own` permits the write (own row only). Note the
  /// consequence, deliberately accepted (Lee, 2026-09-02): `is_internal` is
  /// self-service, so it is a convenience gate for the team, not a paywall —
  /// the paywall remains the `user_entitlements` row only the webhook writes.
  ///
  /// Returns whether the write landed; failures are logged and non-fatal
  /// (the caller retries on the next status resolve).
  Future<bool> mirrorInternalFlag(String userId, bool value) async {
    try {
      await _supabase
          .from('users')
          .update({'is_internal': value})
          .eq('id', userId);
      return true;
    } catch (e, stackTrace) {
      // Expected to fail offline; the next status resolve retries it.
      await _r.degraded(
        e,
        stackTrace: stackTrace,
        area: _area,
        message:
            'Failed to mirror the internal tester flag to users.is_internal',
        extra: {'userId': userId, 'value': value},
      );
      return false;
    }
  }

  /// Fetch the row for [userId] / [entitlement] from Supabase and refresh the
  /// local cache. Returns the resolved status (a missing row resolves to
  /// [SubscriptionStatus.none] and clears the cache), or null when the read
  /// failed — offline, RLS, timeout — so the caller can fall back to
  /// [readCached].
  Future<SubscriptionStatus?> fetchRemote(
    String userId,
    Entitlement entitlement, {
    DateTime? now,
  }) async {
    final Map<String, dynamic>? row;
    try {
      row = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId)
          .eq('entitlement', entitlement.key)
          .maybeSingle();
    } catch (e, stackTrace) {
      // Offline is downgraded by `fault` itself; anything else (RLS, shape)
      // is a real failure of the server-side paywall read.
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Failed to read user_entitlements from Supabase',
        extra: {'userId': userId, 'entitlement': entitlement.key},
      );
      return null;
    }

    try {
      if (row == null) {
        await (_database.delete(_database.userEntitlementsTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.entitlement.equals(entitlement.key),
            ))
            .go();
        return SubscriptionStatus.none;
      }
      await _database
          .into(_database.userEntitlementsTable)
          .insert(
            _companionFromJson(row, fetchedAt: now ?? DateTime.now().toUtc()),
            mode: InsertMode.insertOrReplace,
          );
    } catch (e, stackTrace) {
      // Cache write failures must not hide a successful remote read.
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Failed to cache user_entitlements row',
        extra: {'userId': userId},
      );
    }
    if (row == null) return SubscriptionStatus.none;
    return statusFromRow(
      active: row['active'] == true,
      expiresAt: _parseTimestamp(row['expires_at']),
      periodType: row['period_type'] as String?,
      productId: row['product_id'] as String?,
      now: now ?? DateTime.now().toUtc(),
    );
  }

  /// The cached status for [userId] / [entitlement], or null when nothing is
  /// cached (or the read failed).
  Future<SubscriptionStatus?> readCached(
    String userId,
    Entitlement entitlement, {
    DateTime? now,
  }) async {
    try {
      final entry =
          await (_database.select(_database.userEntitlementsTable)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.entitlement.equals(entitlement.key),
              ))
              .getSingleOrNull();
      if (entry == null) return null;
      return statusFromRow(
        active: entry.active,
        expiresAt: entry.expiresAt?.toUtc(),
        periodType: entry.periodType,
        productId: entry.productId,
        now: now ?? DateTime.now().toUtc(),
      );
    } catch (e, stackTrace) {
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Failed to read cached user_entitlements row',
      );
      return null;
    }
  }

  /// Drop every cached row — called on sign-out so the next account on this
  /// device never inherits the outgoing user's subscription state.
  Future<void> clearCache() async {
    try {
      await _database.delete(_database.userEntitlementsTable).go();
    } catch (e, stackTrace) {
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: _area,
        message: 'Failed to clear user_entitlements cache',
      );
    }
  }

  /// Pure mapping from a server/cache row to a status. Mirrors
  /// `has_entitlement()`: active AND (no expiry OR expiry in the future).
  @visibleForTesting
  static SubscriptionStatus statusFromRow({
    required bool active,
    required DateTime? expiresAt,
    required String? periodType,
    required String? productId,
    required DateTime now,
  }) {
    final unexpired = expiresAt == null || expiresAt.isAfter(now);
    if (!active || !unexpired) return SubscriptionStatus.none;
    final period = periodType?.toUpperCase();
    return SubscriptionStatus(
      active: true,
      expiresAt: expiresAt,
      source: SubscriptionSource.server,
      isTrial: period == 'TRIAL' || period == 'INTRO',
      productId: productId,
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static UserEntitlementsTableCompanion _companionFromJson(
    Map<String, dynamic> row, {
    required DateTime fetchedAt,
  }) {
    return UserEntitlementsTableCompanion(
      userId: Value(row['user_id'] as String),
      entitlement: Value(row['entitlement'] as String),
      active: Value(row['active'] == true),
      productId: Value(row['product_id'] as String?),
      store: Value(row['store'] as String?),
      periodType: Value(row['period_type'] as String?),
      expiresAt: Value(_parseTimestamp(row['expires_at'])),
      source: Value(row['source'] as String? ?? 'revenuecat'),
      updatedAt: Value(_parseTimestamp(row['updated_at']) ?? fetchedAt),
      fetchedAt: Value(fetchedAt),
    );
  }
}
