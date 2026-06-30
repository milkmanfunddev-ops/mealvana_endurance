// ignore_for_file: implementation_imports
//
// Reusable widget-test harness for the screen smoke suite.
//
// Goal: every screen gets at least one widget test that pumps it with mocked
// external deps and asserts it renders without layout overflow across a few
// representative device sizes. Screens that need extra Riverpod overrides
// (AsyncNotifier controllers, family stream providers) pass them via `overrides`.
//
// Builds on `responsive_test_harness.dart` (pumpResponsiveScreen +
// expectNoRenderOverflow + the size constants), which it re-exports.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart'
    show currentUserProvider;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import 'fakes/fake_supabase_client.dart';
import 'responsive_test_harness.dart';

export 'package:flutter_riverpod/src/internals.dart' show Override;
export 'fakes/fake_supabase_client.dart';
export 'responsive_test_harness.dart';

class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

/// A Riverpod override that supplies fully-mocked [AppExternalDeps]
/// (analytics / supabase / sentry / logger / shared-prefs). Most screens read
/// this provider for analytics, and many read `supabaseClient.auth`, so both
/// are stubbed with safe no-op defaults (no current user/session, empty auth
/// stream). Applied by default in [smokeScreen].
Override mockAppExternalDeps() {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  when(() => analytics.markInternal()).thenAnswer((_) async {});

  return appExternalDepsProvider.overrideWithValue(
    AppExternalDeps(
      analytics: analytics,
      supabaseClient: fakeSupabaseClient(),
      sentry: MockSentryReporter(),
      logger: MockAppLogger(),
      sharedPreferences: MockSharedPreferences(),
    ),
  );
}

/// A Riverpod override that provides a no-op [SharedPreferences] mock.
///
/// Added to [smokeScreen] defaults so that build-time reads of
/// [sharedPreferencesProvider] (e.g. from [AnalyticsExcludedNotifier] or
/// [AppThemeModeNotifier]) don't throw [UnimplementedError] in widget tests.
Override mockSharedPreferences() {
  final prefs = MockSharedPreferences();
  when(() => prefs.getBool(any())).thenReturn(null);
  when(() => prefs.getString(any())).thenReturn(null);
  when(() => prefs.getInt(any())).thenReturn(null);
  when(() => prefs.getStringList(any())).thenReturn(null);
  return sharedPreferencesProvider.overrideWithValue(prefs);
}

/// Overrides [appDatabaseProvider] with an in-memory Drift database. Pass a
/// pre-seeded [db] to drive DB-backed screens with real rows; otherwise a fresh
/// empty in-memory database is used. Using this (rather than the real
/// `AppDatabase()`) also silences the "AppDatabase created multiple times"
/// warning across ProviderScopes.
Override inMemoryDatabaseOverride([AppDatabase? db]) =>
    appDatabaseProvider.overrideWithValue(db ?? AppDatabase.memory());

/// Pump [screen] in a seeded environment for **content** assertions (not just
/// "does it render"): mocked external deps (fake Supabase), an in-memory Drift
/// database, mock shared-prefs, and a signed-out current user. Append the
/// screen's own controller/provider overrides (e.g. a fake AsyncNotifier seeded
/// with state) via [overrides].
///
/// By default pumps a couple of frames (loader screens never settle). Pass
/// [settle] true for screens that reach a steady state, or a seeded [database].
Future<void> pumpSeeded(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  AppDatabase? database,
  bool settle = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = database ?? AppDatabase.memory();
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        inMemoryDatabaseOverride(db),
        preferencesServiceProvider.overrideWith((ref) => PreferencesService(prefs)),
        currentUserProvider.overrideWith((ref) async => null),
        ...overrides,
      ],
      child: wrapForTest(screen),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Default device sizes for smoke coverage: small phone, standard phone, tablet.
const List<Size> kSmokeSizes = [
  smallPhoneSize,
  standardPhoneSize,
  tabletPortraitSize,
];

/// Wrap a screen the way the real app root does: inside [ScreenUtilInit] (so
/// `.sp/.h/.w` extensions resolve instead of throwing `LateInitializationError`)
/// + a MaterialApp. Mirrors `root_app_widget.dart` (designSize 393×852).
Widget wrapForTest(Widget screen) => ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => MaterialApp(home: screen),
    );

/// Pump [screen] across [sizes] and assert it builds without throwing.
///
/// Smoke guarantee (always asserted): no exception is thrown during
/// build/layout on any size. This is what "every screen tested once" buys —
/// a screen that crashes on render fails loudly.
///
/// Responsive guarantee (asserted at [overflowSizes], default = standard phone
/// only): no RenderFlex overflow. Narrow 320px overflows are common and noisy,
/// so by default overflow is only enforced at the standard phone width; pass
/// `overflowSizes: kSmokeSizes` to enforce it everywhere.
///
/// Errors are captured deterministically via [FlutterError.onError] (the
/// `takeException()` path is timing-sensitive and can miss late-frame overflow
/// reports). By default applies the mocked [AppExternalDeps] override; pass
/// extra provider overrides (e.g. a seeded AsyncNotifier) via [overrides]. Set
/// [withAppDeps] to false for pure-UI screens that read no providers.
Future<void> smokeScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  List<Size> sizes = const [standardPhoneSize],
  List<Size> overflowSizes = const [standardPhoneSize],
  bool withAppDeps = true,
  bool settle = true,
}) async {
  final allOverrides = <Override>[
    if (withAppDeps) mockAppExternalDeps(),
    // Provide a default SharedPreferences mock so build-time reads of
    // sharedPreferencesProvider (e.g. analyticsExcludedProvider,
    // kyleThemeModeProvider) don't throw UnimplementedError. Individual
    // tests that need custom prefs behaviour can pass their own override
    // in [overrides]; it will appear later in the list and take precedence.
    if (withAppDeps) mockSharedPreferences(),
    ...overrides,
  ];

  bool isOverflow(String s) =>
      s.contains('overflowed') || s.contains('infinite size');

  for (final size in sizes) {
    final captured = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => captured.add(details.exceptionAsString());

    try {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        ProviderScope(overrides: allOverrides, child: wrapForTest(screen)),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // Screens with a perpetual loading indicator never settle; pump a
        // couple of frames so the loading state lays out, then move on.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      FlutterError.onError = previousOnError;
    }

    // Also drain anything the binding recorded directly.
    for (dynamic e = tester.takeException(); e != null; e = tester.takeException()) {
      captured.add(e.toString());
    }

    final crashes = captured.where((s) => !isOverflow(s)).toList();
    expect(
      crashes,
      isEmpty,
      reason: '${screen.runtimeType} threw during build/layout at $size:\n'
          '${crashes.join('\n\n')}',
    );

    final enforceOverflow = overflowSizes.contains(size);
    final overflows = captured.where(isOverflow).toList();
    if (enforceOverflow) {
      expect(
        overflows,
        isEmpty,
        reason: '${screen.runtimeType} render overflow at $size:\n'
            '${overflows.join('\n')}',
      );
    }
  }

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
