// Golden + contract conformance — performance-value source provenance.
// Manifest: docs/ssot/conformance/design/ftp-source-provenance.goldens.yaml
// (RATIFIED; Q-DID2 RULED 2026-09-11: variant A — chip is SOURCE ONLY, no
// relative time; manual-wins; inline conflict, NEVER a modal). Rendering:
// docs/ssot/spec/design/renderings/ftp-source-provenance@v1.html.
//
// The states render the ONE shared chip family (KyleSourceProvenanceRow /
// KyleSourceChip / KyleStaleChip / KyleTapToUseChip) that the FTP and CSS
// fields compose — per the handoff's component-reuse rule, the goldens pin
// the single implementation every application (FTP/CSS, body composition,
// events) shares.
//
// Regenerate with --update-goldens ONLY after a design-spec change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/data/kyle_source_chip.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

import '../home_shell/home_shell_test_fonts.dart';

Widget _frame(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.blackberryDark,
        body: Center(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

void main() {
  setUpAll(loadHomeShellFonts);

  Future<void> golden(
    WidgetTester tester,
    Widget row,
    String file,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 120));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_frame(row));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(KyleSourceProvenanceRow),
      matchesGoldenFile(file),
    );
  }

  group('goldens', () {
    testWidgets('ftp-manual', (tester) async {
      await golden(
        tester,
        KyleSourceProvenanceRow(
          manualValue: 250,
          providerValue: null,
          unit: 'W',
          onAdoptProvider: (_) {},
        ),
        'goldens/ftp_provenance_manual.png',
      );
    });

    testWidgets('ftp-tp-sourced — source only, no relative time',
        (tester) async {
      await golden(
        tester,
        KyleSourceProvenanceRow(
          manualValue: 240,
          providerValue: 240,
          unit: 'W',
          onAdoptProvider: (_) {},
        ),
        'goldens/ftp_provenance_tp_sourced.png',
      );
    });

    testWidgets('ftp-conflict-a', (tester) async {
      await golden(
        tester,
        KyleSourceProvenanceRow(
          manualValue: 250,
          providerValue: 240,
          unit: 'W',
          onAdoptProvider: (_) {},
        ),
        'goldens/ftp_provenance_conflict_a.png',
      );
    });

    testWidgets('ftp-stale', (tester) async {
      await golden(
        tester,
        KyleSourceProvenanceRow(
          manualValue: 240,
          providerValue: 240,
          stale: true,
          unit: 'W',
          onAdoptProvider: (_) {},
        ),
        'goldens/ftp_provenance_stale.png',
      );
    });

    testWidgets('css-inherits — same pattern, CSS parameters',
        (tester) async {
      await golden(
        tester,
        KyleSourceProvenanceRow(
          manualValue: 95,
          providerValue: 92,
          unit: 's/100m',
          onAdoptProvider: (_) {},
        ),
        'goldens/css_provenance_conflict.png',
      );
    });
  });

  group('contract assertions (Q-DID2 variant A)', () {
    testWidgets('TP-sourced chip is SOURCE ONLY — no relative time, no '
        'value', (tester) async {
      await tester.pumpWidget(_frame(KyleSourceProvenanceRow(
        manualValue: null,
        providerValue: 240,
        onAdoptProvider: (_) {},
      )));
      expect(find.text('TrainingPeaks'), findsOneWidget);
      expect(find.textContaining('ago'), findsNothing);
      expect(find.textContaining('240'), findsNothing);
    });

    testWidgets('conflict shows manual-wins pairing with the single-tap '
        'adopt affordance and NO modal', (tester) async {
      int? adopted;
      await tester.pumpWidget(_frame(KyleSourceProvenanceRow(
        manualValue: 250,
        providerValue: 240,
        unit: 'W',
        onAdoptProvider: (v) => adopted = v,
      )));
      expect(find.text('Manual · 250 W'), findsOneWidget);
      expect(
        find.text('TrainingPeaks · 240 W — tap to use'),
        findsOneWidget,
      );
      await tester.tap(find.text('TrainingPeaks · 240 W — tap to use'));
      await tester.pump();
      expect(adopted, 240, reason: 'a single tap adopts the provider value');
      expect(find.byType(Dialog), findsNothing, reason: 'never a modal');
    });

    testWidgets('stale chip appears only past the window and only with a '
        'provider value', (tester) async {
      await tester.pumpWidget(_frame(KyleSourceProvenanceRow(
        manualValue: 250,
        providerValue: null,
        stale: true,
        onAdoptProvider: (_) {},
      )));
      expect(find.text('stale'), findsNothing);

      await tester.pumpWidget(_frame(KyleSourceProvenanceRow(
        manualValue: 240,
        providerValue: 240,
        stale: true,
        onAdoptProvider: (_) {},
      )));
      expect(find.text('stale'), findsOneWidget);
    });

    testWidgets('the same widget parameterizes for body composition and '
        'events (one implementation, three applications)', (tester) async {
      await tester.pumpWidget(_frame(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // D-2b: body composition — Manual · Garmin, 30 d window.
          KyleSourceProvenanceRow(
            manualValue: 154,
            providerValue: 152,
            providerName: 'Garmin',
            unit: 'lb',
            onAdoptProvider: (_) {},
          ),
          const SizedBox(height: 12),
          // D-2c: events — per-row origin, no window.
          const KyleSourceChip(source: 'Final Surge'),
        ],
      )));
      expect(find.text('Garmin · 152 lb — tap to use'), findsOneWidget);
      expect(find.text('Final Surge'), findsOneWidget);
    });
  });
}
