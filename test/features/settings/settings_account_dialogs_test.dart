// Settings' sign-out and delete-account confirms (ticket 47, mp-508).
//
// mp-508: there is no guest mode, so the sign-out confirm says the athlete
// will need to sign in again to use the app and never mentions a guest.
// Finding 02-006: the delete-account confirm uses the paywall's content keys,
// so the two delete confirms read the same.
//
// Each dialog is checked twice: once against sentinel content (proves every
// string comes from the content system, none is a literal), once against the
// bundled defaults (proves what the athlete actually reads).

// ignore_for_file: must_be_immutable

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/settings_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

class _Calls {
  int signOuts = 0;
  int deletes = 0;
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController(this._calls);

  final _Calls _calls;

  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
    isAnonymous: false,
    authProvider: 'apple',
    email: 'athlete@example.com',
    signOutButton: 'Sign Out',
  );

  @override
  Future<void> signOut() async => _calls.signOuts++;

  @override
  Future<void> deleteAccount() async => _calls.deletes++;
}

final _defaults = loadDefaultContent();

/// Every key the two dialogs read, mapped to a sentinel no literal could match.
const _dialogKeys = [
  ContentKeys.paywallSignOutConfirmTitle,
  ContentKeys.settingsSignOutConfirmBody,
  ContentKeys.paywallSignOutButton,
  ContentKeys.paywallCancel,
  ContentKeys.paywallDeleteAccountButton,
  ContentKeys.paywallDeleteConfirmTitle,
  ContentKeys.paywallDeleteConfirmBody,
  ContentKeys.paywallDeleteConfirmAction,
];

Map<String, String> _sentinels() => {
  ..._defaults,
  for (final key in _dialogKeys) key: '«$key»',
};

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Map<String, String> content,
  required _Calls calls,
}) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/welcome',
        builder: (_, __) => const Scaffold(body: Text('welcome')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
        contentServiceProvider.overrideWith(
          (ref) => TestContentService(ref, content),
        ),
        settingsControllerProvider.overrideWith(
          () => _SeededSettingsController(calls),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get _signOutButton =>
    find.byKey(const ValueKey('settings.sign_out_button'));
Finder get _deleteButton =>
    find.byKey(const ValueKey('settings.delete_account_button'));

/// All the text shown inside the open dialog, joined.
String _dialogText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  group('Sign-out confirm (mp-508)', () {
    testWidgets('every string comes from the content system', (tester) async {
      final content = _sentinels();
      await _pumpSettings(tester, content: content, calls: _Calls());

      await _tap(tester, _signOutButton);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      for (final key in [
        ContentKeys.paywallSignOutConfirmTitle,
        ContentKeys.settingsSignOutConfirmBody,
        ContentKeys.paywallSignOutButton,
        ContentKeys.paywallCancel,
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.text(content[key]!)),
          findsOneWidget,
          reason: '$key is not what the dialog shows',
        );
      }
      expect(
        find.descendant(of: dialog, matching: find.byType(Text)),
        findsNWidgets(4),
        reason: 'a fifth string would be a literal',
      );
    });

    testWidgets('says they will sign in again, never mentions a guest, and '
        'signs out on confirm', (tester) async {
      final calls = _Calls();
      await _pumpSettings(tester, content: _defaults, calls: calls);

      await _tap(tester, _signOutButton);

      final text = _dialogText(tester);
      expect(text.toLowerCase(), isNot(contains('guest')));
      expect(
        _defaults[ContentKeys.settingsSignOutConfirmBody]!.toLowerCase(),
        contains('sign in again'),
      );
      expect(text, contains(_defaults[ContentKeys.settingsSignOutConfirmBody]));

      await _tap(tester, find.byKey(const ValueKey('settings.confirm.action')));
      expect(calls.signOuts, 1);
      expect(find.text('welcome'), findsOneWidget);
    });

    testWidgets('Cancel keeps the athlete signed in', (tester) async {
      final calls = _Calls();
      await _pumpSettings(tester, content: _defaults, calls: calls);

      await _tap(tester, _signOutButton);
      await _tap(tester, find.byKey(const ValueKey('settings.confirm.cancel')));

      expect(calls.signOuts, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Delete-account confirm (finding 02-006)', () {
    testWidgets('the button and every dialog string come from the content '
        'system', (tester) async {
      final content = _sentinels();
      await _pumpSettings(tester, content: content, calls: _Calls());

      expect(
        find.descendant(
          of: _deleteButton,
          matching: find.text(content[ContentKeys.paywallDeleteAccountButton]!),
        ),
        findsOneWidget,
      );

      await _tap(tester, _deleteButton);

      final dialog = find.byType(AlertDialog);
      for (final key in [
        ContentKeys.paywallDeleteConfirmTitle,
        ContentKeys.paywallDeleteConfirmBody,
        ContentKeys.paywallDeleteConfirmAction,
        ContentKeys.paywallCancel,
      ]) {
        expect(
          find.descendant(of: dialog, matching: find.text(content[key]!)),
          findsOneWidget,
          reason: '$key is not what the dialog shows',
        );
      }
      expect(
        find.descendant(of: dialog, matching: find.byType(Text)),
        findsNWidgets(4),
        reason: 'a fifth string would be a literal',
      );
    });

    testWidgets('reads the same as the paywall delete confirm and deletes on '
        'confirm', (tester) async {
      final calls = _Calls();
      await _pumpSettings(tester, content: _defaults, calls: calls);

      await _tap(tester, _deleteButton);

      // The paywall's confirm renders exactly these four keys
      // (paywall_screen.dart `_deleteAccount`, pinned by paywall_screen_test).
      expect(
        _dialogText(tester),
        [
          _defaults[ContentKeys.paywallDeleteConfirmTitle],
          _defaults[ContentKeys.paywallDeleteConfirmBody],
          _defaults[ContentKeys.paywallCancel],
          _defaults[ContentKeys.paywallDeleteConfirmAction],
        ].join(' | '),
      );

      await _tap(tester, find.byKey(const ValueKey('settings.confirm.action')));
      expect(calls.deletes, 1);
      expect(calls.signOuts, 0);
      expect(find.text('welcome'), findsOneWidget);
    });
  });
}
