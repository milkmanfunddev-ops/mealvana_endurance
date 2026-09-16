// Golden + gesture conformance — TP write-back consent (opt-out).
// Manifest: docs/ssot/conformance/design/tp-writeback-consent.goldens.yaml
// (RATIFIED; Q-INT16 AMENDED to opt-out 2026-09-11). Rendering:
// docs/ssot/spec/design/renderings/tp-writeback-consent@v1.html.
//
// Goldens realized here:
//   sheet-opt-out-notice  — the sheet: title, body, EXAMPLE block with the
//                           amended TP-5 register (g/hr · ml/hr · mg/hr),
//                           Keep Sharing (filled) + Turn Off Sharing
//                           (outline) + dismiss X, footer.
//   tp-row-toggle-on      — bare "Write fuel plan to TrainingPeaks" toggle,
//                           PRE-SET ON.
//   premium-blocked       — ratified copy + Re-check, NO dead toggle.
// (onboarding-variant renders the SAME sheet widget — pinned by the
// sheet golden plus the connect-path wiring in connected_apps_screen.)
//
// Gestures: dismiss-leaves-on (X pops null — callers keep sharing ON),
// turn-off-flips-toggle (single tap pops false), and opt-out-visibility
// (Turn Off Sharing fully visible without scrolling on the smallest
// supported screen).
//
// Regenerate with --update-goldens ONLY after a design-spec change.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/settings/presentation/widgets/tp_writeback_toggle_row.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/sheets/tp_writeback_consent_sheet.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../home_shell/home_shell_test_fonts.dart';

Widget _frame(Widget child, {Size size = const Size(390, 760)}) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          backgroundColor: AppColors.blackberryDark,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<PreferencesService> _prefs(
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  return PreferencesService(await SharedPreferences.getInstance());
}

Widget _rowFrame(PreferencesService prefs) {
  return ProviderScope(
    overrides: [preferencesServiceProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.blackberry,
        body: Center(
          child: TpWritebackToggleRow(onRecheck: () {}),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadHomeShellFonts);

  group('goldens', () {
    testWidgets('sheet-opt-out-notice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_frame(const TpWritebackConsentSheet()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TpWritebackConsentSheet),
        matchesGoldenFile('goldens/tp_writeback_consent_sheet.png'),
      );
    });

    testWidgets('tp-row-toggle-on', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 120));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_rowFrame(await _prefs({})));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TpWritebackToggleRow),
        matchesGoldenFile('goldens/tp_writeback_row_toggle_on.png'),
      );
    });

    testWidgets('premium-blocked', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 120));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _rowFrame(await _prefs({'tp_writeback_premium_blocked': true})),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(TpWritebackToggleRow),
        matchesGoldenFile('goldens/tp_writeback_row_premium_blocked.png'),
      );
    });
  });

  group('contract assertions', () {
    testWidgets('the sheet carries the ratified copy and the amended '
        'register example', (tester) async {
      await tester.pumpWidget(_frame(const TpWritebackConsentSheet()));
      await tester.pumpAndSettle();
      expect(find.text('Your fuel plan goes to your coach'), findsOneWidget);
      expect(
        find.text('60 g carbs/hr · 500 ml/hr · 400 mg sodium/hr'),
        findsOneWidget,
      );
      expect(find.text('Keep Sharing'), findsOneWidget);
      expect(find.text('Turn Off Sharing'), findsOneWidget);
      expect(find.text('Closing this leaves sharing on.'), findsOneWidget);
    });

    testWidgets('tp-row-toggle-on: bare toggle PRE-SET ON with the ratified '
        'label', (tester) async {
      await tester.pumpWidget(_rowFrame(await _prefs({})));
      await tester.pumpAndSettle();
      expect(find.text('Write fuel plan to TrainingPeaks'), findsOneWidget);
      // Sublabel struck 2026-09-11 — the toggle is bare.
      expect(
        find.textContaining('nutrition plan summary'),
        findsNothing,
      );
    });

    testWidgets('premium-blocked: ratified copy + Re-check, no dead toggle',
        (tester) async {
      await tester.pumpWidget(
        _rowFrame(await _prefs({'tp_writeback_premium_blocked': true})),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unavailable for your TrainingPeaks plan'),
        findsOneWidget,
      );
      expect(find.text('Re-check'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connected_apps.tp_writeback_toggle')),
        findsNothing,
        reason: 'no dead toggle while blocked',
      );
    });
  });

  group('gestures', () {
    testWidgets('dismiss-leaves-on: the X pops null (callers keep ON)',
        (tester) async {
      bool? result = true; // sentinel
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await TpWritebackConsentSheet.show(context);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('kyle_sheet_header.close')));
      await tester.pumpAndSettle();
      expect(result, isNull, reason: 'dismiss must resolve null — the '
          'caller treats null as KEEP SHARING ON');
    });

    testWidgets('turn-off-flips-toggle: a single tap pops false',
        (tester) async {
      bool? result = true;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await TpWritebackConsentSheet.show(context);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('tp_writeback_consent.turn_off')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('opt-out-visibility: Turn Off Sharing fully visible without '
        'scrolling on the smallest supported screen', (tester) async {
      // The ratified layout constraint — the export artboards clipped it.
      const smallest = Size(320, 568);
      await tester.binding.setSurfaceSize(smallest);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _frame(const TpWritebackConsentSheet(), size: smallest),
      );
      await tester.pumpAndSettle();
      final turnOff =
          find.byKey(const ValueKey('tp_writeback_consent.turn_off'));
      expect(turnOff, findsOneWidget);
      final rect = tester.getRect(turnOff);
      expect(rect.bottom, lessThanOrEqualTo(smallest.height));
      expect(rect.top, greaterThanOrEqualTo(0));
    });
  });
}
