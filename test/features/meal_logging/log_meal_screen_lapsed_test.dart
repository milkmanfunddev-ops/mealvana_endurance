/// A lapsed account's AI tap on the log-meal screen (mp-457 §3, ticket 11).
///
/// The log-meal screen is a plain page push the router never sees, so its
/// Analyze button asks `aiActionAllowed` itself. Through the real screen: a
/// lapsed account (write access no) taps Analyze on the Describe tab, the
/// paywall opens over the screen, and `describe-meal` is never called.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/features/subscription/presentation/pro_gate_redirect.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/supabase/supabase_client_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/helpers/fakes.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  testWidgets('a lapsed account tapping Analyze meets the paywall, not the AI', (
    tester,
  ) async {
    final supabase = supabaseWithSession();
    final functions = _MockFunctions();
    when(() => supabase.functions).thenReturn(functions);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const LogMealScreen(logDate: '2026-09-22', source: 'test'),
        ),
        GoRoute(
          path: kPaywallPath,
          builder: (_, __) => const Scaffold(body: Text('paywall')),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          supabaseClientProvider.overrideWithValue(supabase),
          contentServiceProvider.overrideWith(testContentService),
          writeAccessProvider.overrideWith((_) async => false),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Describe'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'porridge and a banana');
    await tester.pump();

    await tester.tap(find.text('Analyze'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('paywall'), findsOneWidget);
    verifyNever(() => functions.invoke(any(), body: any(named: 'body')));
  });
}
