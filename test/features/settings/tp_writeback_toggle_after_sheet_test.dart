// 69-009 (develop-2026-10 ticket 82): after a TrainingPeaks connect, Turn Off
// Sharing on the "Your fuel plan goes to your coach" sheet wrote the pref off,
// but the card's "Write fuel plan to TrainingPeaks" toggle stayed on until
// Connected Apps was reopened.
//
// The real ConnectedAppsScreen, the real consent sheet, the real toggle row
// and PreferencesService over real SharedPreferences (mock initial values).
// The seam is the controller's answer to Connect: a ConnectTrainingController
// whose connectTrainingPeaks says yes and flips TrainingPeaks to connected
// (OAuth is not under test).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/kyle_switch.dart';

import '../../helpers/widget_test_harness.dart';
import '../../helpers/test_content.dart';

/// TrainingPeaks starts disconnected; Connect succeeds and the card flips to
/// connected. [build] reads [_connected] so the screen's own invalidate on
/// open does not undo a connect.
class _ConnectsTrainingPeaks extends ConnectTrainingController {
  static bool _connected = false;

  @override
  FutureOr<ConnectTrainingState> build() =>
      ConnectTrainingState(isTrainingPeaksConnected: _connected);

  @override
  Future<bool> connectTrainingPeaks() async {
    _connected = true;
    state = const AsyncData(
      ConnectTrainingState(
        isTrainingPeaksConnected: true,
        trainingPeaksAthleteName: 'Test Athlete',
      ),
    );
    return true;
  }
}

const _tpCard = 'connected_apps.trainingpeaks_connect_button';
const _toggle = ValueKey('connected_apps.tp_writeback_toggle');

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    _ConnectsTrainingPeaks._connected = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> connectAndAnswer(
    WidgetTester tester,
    ValueKey<String> choice,
  ) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          sharedPreferencesProvider.overrideWithValue(prefs),
          inMemoryDatabaseOverride(db),
          contentServiceProvider.overrideWith(testContentService),
          connectTrainingControllerProvider.overrideWith(
            _ConnectsTrainingPeaks.new,
          ),
        ],
        // Settings mode: no onContinue.
        child: wrapForTest(const ConnectedAppsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_toggle), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(_tpCard)),
        matching: find.text('Connect'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(choice));
    await tester.pumpAndSettle();

    // Let the "TrainingPeaks connected!" bar's timer run out inside the test
    // body (#110).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  bool toggleValue(WidgetTester tester) =>
      tester.widget<KyleSwitch>(find.byKey(_toggle)).value;

  testWidgets('Turn Off Sharing: the toggle reads off at once, without a '
      'reopen, and the pref is off', (tester) async {
    await connectAndAnswer(
      tester,
      const ValueKey('tp_writeback_consent.turn_off'),
    );

    expect(PreferencesService(prefs).tpWritebackEnabled, isFalse);
    expect(toggleValue(tester), isFalse);
  });

  testWidgets('Keep Sharing: the toggle and the pref stay on', (tester) async {
    await connectAndAnswer(
      tester,
      const ValueKey('tp_writeback_consent.keep_sharing'),
    );

    expect(PreferencesService(prefs).tpWritebackEnabled, isTrue);
    expect(toggleValue(tester), isTrue);
  });
}
