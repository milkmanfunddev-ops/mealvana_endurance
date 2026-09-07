import 'package:drift/drift.dart';

/// Local mirror of the user's own `public.user_entitlements` rows — the Pro
/// subscription state the RevenueCat webhook writes server-side
/// (docs/implement_mealplanning/04-entitlement.md).
///
/// READ-ONLY CACHE. The client never writes this table to Supabase (RLS is
/// owner-select, service_role-write), so there is no `needs_upload` column and
/// it is not a SyncableRepository. It exists so the Pro gate can be answered
/// offline / before RevenueCat has answered on a cold start.
///
/// Primary key mirrors the server: (user_id, entitlement).
@DataClassName('UserEntitlementEntry')
class UserEntitlementsTable extends Table {
  TextColumn get userId => text().named('user_id')();

  /// Entitlement key, e.g. 'pro' (see `Entitlement.key`).
  TextColumn get entitlement => text()();

  BoolColumn get active =>
      boolean().withDefault(const Constant(false))();

  /// Store SKU that granted the entitlement.
  TextColumn get productId => text().nullable().named('product_id')();

  /// APP_STORE | PLAY_STORE | PROMOTIONAL | … (RevenueCat store string).
  TextColumn get store => text().nullable()();

  /// NORMAL | TRIAL | INTRO | PROMOTIONAL.
  TextColumn get periodType => text().nullable().named('period_type')();

  DateTimeColumn get expiresAt =>
      dateTime().nullable().named('expires_at')();

  /// revenuecat | promo | internal.
  TextColumn get source =>
      text().withDefault(const Constant('revenuecat'))();

  /// Server `updated_at` (= RevenueCat event timestamp).
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// When this device last fetched the row — staleness signal for the cache.
  DateTimeColumn get fetchedAt => dateTime().named('fetched_at')();

  @override
  Set<Column> get primaryKey => {userId, entitlement};

  @override
  String get tableName => 'user_entitlements';
}
