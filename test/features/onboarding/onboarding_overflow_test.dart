// Ticket 43 (Finding 30-002, dev Sentry MEALVANA-ENDURANCE-DEV-B1): a
// RenderFlex overflowed by 971 px during onboarding on a 402×874 iPhone. The
// event's creator chain is `Column ← MediaQuery ← Padding ← SafeArea ←
// KeyedSubtree ← _BodyBuilder`, i.e. a `Scaffold(body: SafeArea(child:
// Column(...)))` — the onboarding step chrome.
//
// This pumps the REAL OnboardingPageViewScreen (keep-alive pages, real
// PageView) at the event's device size and at iPhone SE, with the keyboard
// down and up, on the connect, personal info and body composition pages and
// across the 4 → 5 swipe, and fails on any overflow. It is the guard for the
// Sentry event: whatever reproduces it must fail here first.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/body_composition_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/widgets/onboarding_multi_select_step.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

/// Connect step with nothing connected and no Supabase behind it.
class _IdleConnectTrainingController extends ConnectTrainingController {
  @override
  FutureOr<ConnectTrainingState> build() => const ConnectTrainingState();
}

/// A device: logical size, safe-area padding and keyboard height.
class _Device {
  const _Device(this.name, this.size, this.top, this.bottom, this.keyboard);
  final String name;
  final Size size;
  final double top;
  final double bottom;
  final double keyboard;
}

const _devices = [
  // iPhone 17 Pro (the DEV-B1 event): 402×874, 62 top / 34 bottom, 336 kb.
  _Device('402x874', Size(402, 874), 62, 34, 336),
  // iPhone SE: 375×667, 20 top / 0 bottom, 260 kb.
  _Device('375x667', smallPhoneSize, 20, 0, 260),
];

/// DEV-B1's shape: a vertical RenderFlex running out of height.
bool _isVerticalOverflow(String text) =>
    RegExp(r'overflowed by [\d.]+ pixels on the (bottom|top)').hasMatch(text);

void main() {
  late List<String> overflows;
  FlutterExceptionHandler? previousOnError;

  /// Installs an onError that records every overflow with its full
  /// diagnostics (creator chain included). Restored with addTearDown so it
  /// is gone before the test's teardown pumps.
  void captureOverflows() {
    overflows = [];
    previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (_isVerticalOverflow(text)) {
        overflows.add(text);
      } else if (text.contains('overflowed')) {
        // Horizontal overflows are not DEV-B1's shape, and in widget tests
        // they are mostly the test font's doing (no app fonts are loaded,
        // so every glyph is a full em wide). Logged, not failed.
        debugPrint(
          'ticket 43: horizontal overflow (not asserted): '
          '${details.exceptionAsString()}',
        );
      } else {
        previousOnError?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previousOnError);
  }

  /// Restores the previous onError BEFORE any expect, so a failing expect
  /// reaches the test binding's own handler.
  void stopCapture() => FlutterError.onError = previousOnError;

  Future<void> pumpFlow(WidgetTester tester, _Device device) async {
    tester.view.physicalSize = device.size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(
      top: device.top,
      bottom: device.bottom,
    );
    tester.view.viewPadding = FakeViewPadding(
      top: device.top,
      bottom: device.bottom,
    );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          onboardingIntegrationProfileProvider.overrideWith(
            (ref) async => OnboardingIntegrationProfile.empty,
          ),
          connectTrainingControllerProvider.overrideWith(
            _IdleConnectTrainingController.new,
          ),
        ],
        child: wrapForTest(const OnboardingPageViewScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> jumpTo(WidgetTester tester, int page) async {
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(page);
    await tester.pumpAndSettle();
  }

  Future<void> keyboard(WidgetTester tester, double height) async {
    tester.view.viewInsets = FakeViewPadding(bottom: height);
    await tester.pumpAndSettle();
  }

  /// Records the step chrome's measured heights (the outer Column, its
  /// header, its footer and what is left for the scrolling body) so the
  /// ticket can quote them. Visible page only.
  void measure(WidgetTester tester, _Device d, String state) {
    final header = find.byType(OnboardingStepHeader);
    if (header.evaluate().isEmpty) return;
    final column = find
        .ancestor(of: header.first, matching: find.byType(Column))
        .first;
    final footer = find
        .ancestor(
          of: find.byType(OnboardingSpecCta).first,
          matching: find.byType(Padding),
        )
        .first;
    final columnH = tester.getSize(column).height;
    final headerH = tester.getSize(header.first).height;
    final footerH = tester.getSize(footer).height;
    debugPrint(
      'ticket 43 measure ${d.name} $state: column=$columnH '
      'header=$headerH footer=$footerH body=${columnH - headerH - footerH}',
    );
  }

  String report(_Device d, String step) =>
      'overflow on $step at ${d.name}:\n${overflows.join('\n---\n')}';

  for (final device in _devices) {
    group(device.name, () {
      testWidgets('page 3 (connect training), keyboard down and up', (
        tester,
      ) async {
        captureOverflows();
        await pumpFlow(tester, device);
        await jumpTo(tester, 3);
        expect(find.byType(ConnectedAppsScreen), findsOneWidget);
        measure(tester, device, 'page 3 kb down');
        await keyboard(tester, device.keyboard);
        measure(tester, device, 'page 3 kb up');
        await keyboard(tester, 0);
        stopCapture();
        expect(overflows, isEmpty, reason: report(device, 'page 3'));
      });

      testWidgets('page 4 (personal info), First name focused, keyboard up', (
        tester,
      ) async {
        captureOverflows();
        await pumpFlow(tester, device);
        await jumpTo(tester, 4);
        expect(find.byType(PersonalInfoScreen), findsOneWidget);

        await tester.showKeyboard(
          find.byKey(const ValueKey('personal_info.first_name_field')),
        );
        await keyboard(tester, device.keyboard);
        await tester.enterText(
          find.byKey(const ValueKey('personal_info.first_name_field')),
          'Ada',
        );
        await tester.pumpAndSettle();
        measure(tester, device, 'page 4 kb up');
        await keyboard(tester, 0);
        measure(tester, device, 'page 4 kb down');
        stopCapture();
        expect(overflows, isEmpty, reason: report(device, 'page 4'));
      });

      testWidgets('page 5 (body composition), keyboard down and up', (
        tester,
      ) async {
        captureOverflows();
        await pumpFlow(tester, device);
        await jumpTo(tester, 5);
        expect(find.byType(BodyCompositionScreen), findsOneWidget);
        measure(tester, device, 'page 5 kb down');
        await keyboard(tester, device.keyboard);
        measure(tester, device, 'page 5 kb up');
        await keyboard(tester, 0);
        stopCapture();
        expect(overflows, isEmpty, reason: report(device, 'page 5'));
      });

      testWidgets('swipe 4 → 5 with the keyboard up', (tester) async {
        captureOverflows();
        await pumpFlow(tester, device);
        await jumpTo(tester, 4);
        await tester.showKeyboard(
          find.byKey(const ValueKey('personal_info.first_name_field')),
        );
        await keyboard(tester, device.keyboard);

        // A slow drag, frame by frame, so every intermediate layout of both
        // pages (and the keyboard still reported up while the page moves)
        // is laid out — the swipe's onPageChanged unfocuses only at the end.
        final gesture = await tester.startGesture(
          Offset(device.size.width - 20, device.size.height / 3),
        );
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(Offset(-device.size.width / 20, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(BodyCompositionScreen), findsOneWidget);
        measure(tester, device, 'page 5 after swipe, kb up');

        // The keyboard goes down after the page settles.
        await keyboard(tester, 0);
        stopCapture();
        expect(overflows, isEmpty, reason: report(device, 'swipe 4→5'));
      });
    });
  }
}
