/// D-2 — the provenance row lives on the surface the athlete actually
/// reaches. The settings hub routes Cycling/Swimming to the onboarding-reuse
/// detail screens (`/settings/cycling-details`, `/settings/swimming-details`),
/// NOT to SportSettingsScreen — the 2026-09-11 sim charter walk caught the
/// chips composed only on the unrouted screen. This pins the live one.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/cycling_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/swimming_details_screen.dart';
import 'package:mealvana_endurance/shared/core/screen_mode.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/kyle_source_chip.dart';

import '../../helpers/fixtures/user_fixtures.dart';
import '../../helpers/widget_test_harness.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  late _MockAuthService auth;

  setUp(() {
    auth = _MockAuthService();
    when(() => auth.getCurrentUser()).thenAnswer(
      (_) async => UserFixtures.completedUser(id: 'u-live'),
    );
  });

  testWidgets('cycling details (settings mode) composes the D-2 row', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const CyclingDetailsScreen(mode: ScreenMode.settings),
      overrides: [authServiceProvider.overrideWithValue(auth)],
      // Settings mode has a PRE-EXISTING 14 px right overflow at 390 pt
      // (present before the D-2 row; filed 2026-09-11). This test pins
      // composition, not layout.
      overflowSizes: const [],
    );
    expect(find.byType(KyleSourceProvenanceRow), findsOneWidget);
  });

  testWidgets('swimming details (settings mode) composes the D-2 row', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const SwimmingDetailsScreen(mode: ScreenMode.settings),
      overrides: [authServiceProvider.overrideWithValue(auth)],
      // Same pre-existing settings-mode overflow (34 px) — see above.
      overflowSizes: const [],
    );
    expect(find.byType(KyleSourceProvenanceRow), findsOneWidget);
  });
}
