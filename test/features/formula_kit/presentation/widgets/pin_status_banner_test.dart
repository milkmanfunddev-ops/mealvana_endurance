import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/pin_status_banner.dart';

// Locks in the substep 11 polish rules for the PinStatusBanner:
//   - Two-state copy for non-honored rows
//       pinSetSize == 0  → "No pin found"
//       pinSetSize  > 0  → "Pins fell through"
//   - Honored rows show the pinned template's display name
//   - CTA copy reads "Pin your favorite formula" (the arrow trailing it is
//     an Icon, not text)
//
// In V1 the only fallthrough reason is `no_pin_for_scope`, so almost every
// non-honored row renders as "No pin found"; the "Pins fell through" branch
// is wired forward-compat for future fallthrough reasons (allergen, season,
// etc.) and becomes load-bearing without a code change.

PinDecision _honored({
  String name = 'Bagel + Jam',
  String id = 'tpl-bagel',
  int setSize = 1,
}) => PinDecision(
  usedPin: true,
  pinnedTemplateId: id,
  pinnedTemplateName: name,
  fallthroughReason: null,
  pinSetSize: setSize,
);

const _noPinForScope = PinDecision(
  usedPin: false,
  pinnedTemplateId: null,
  pinnedTemplateName: null,
  fallthroughReason: PinFallthroughReason.noPinForScope,
  pinSetSize: 0,
);

/// V2-style fallthrough: pins existed in scope but weren't selected. V1
/// doesn't currently emit this shape (only reason is no_pin_for_scope), but
/// the widget contract supports it forward-compat.
const _fellThrough = PinDecision(
  usedPin: false,
  pinnedTemplateId: null,
  pinnedTemplateName: null,
  fallthroughReason: PinFallthroughReason.noPinForScope,
  pinSetSize: 3,
);

Widget _host(
  List<PinStatusBannerRow> rows, {
  VoidCallback? onCta,
  bool isOnboarding = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PinStatusBanner(
          rows: rows,
          isOnboarding: isOnboarding,
          onFormulaLibraryTapped: onCta,
        ),
      ),
    ),
  );
}

Future<void> _expand(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('pin_status_banner.header')));
  // Allow expand animation + chevron rotation to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  group('PinStatusBanner — header summary', () {
    testWidgets('all honored → "Using your pinned formulas" + N pins honored', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(
            label: 'Meal',
            decision: _honored(name: 'Bagel'),
          ),
          PinStatusBannerRow(
            label: 'Snack',
            decision: _honored(name: 'OJ'),
          ),
        ]),
      );
      expect(find.text('Using your pinned formulas'), findsOneWidget);
      expect(find.text('2 pins honored'), findsOneWidget);
    });

    testWidgets("zero honored → \"Pin didn't apply to this workout\"", (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(label: 'Meal', decision: _noPinForScope),
          PinStatusBannerRow(label: 'During', decision: _noPinForScope),
        ]),
      );
      expect(find.text("Pin didn't apply to this workout"), findsOneWidget);
      expect(find.text('No in-scope pin for this activity'), findsOneWidget);
    });

    testWidgets('mixed → "Some pins honored, some skipped" + counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(label: 'Meal', decision: _honored()),
          PinStatusBannerRow(label: 'Snack', decision: _noPinForScope),
          PinStatusBannerRow(label: 'During', decision: _noPinForScope),
        ]),
      );
      expect(find.text('Some pins honored, some skipped'), findsOneWidget);
      expect(find.text('1 honored · 2 skipped'), findsOneWidget);
    });
  });

  group('PinStatusBanner — row copy (two-state rule)', () {
    testWidgets('honored row shows the pinned template name', (tester) async {
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(
            label: 'Snack',
            decision: _honored(name: 'OJ + Toast'),
          ),
        ]),
      );
      await _expand(tester);
      expect(find.text('OJ + Toast'), findsOneWidget);
    });

    testWidgets(
      'honored row falls back to "Pinned formula" when name is null',
      (tester) async {
        const namelessPin = PinDecision(
          usedPin: true,
          pinnedTemplateId: 'tpl-x',
          pinnedTemplateName: null,
          fallthroughReason: null,
          pinSetSize: 1,
        );
        await tester.pumpWidget(
          _host([PinStatusBannerRow(label: 'Meal', decision: namelessPin)]),
        );
        await _expand(tester);
        expect(find.text('Pinned formula'), findsOneWidget);
      },
    );

    testWidgets('non-honored row with pin_set_size == 0 → "No pin found"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([PinStatusBannerRow(label: 'During', decision: _noPinForScope)]),
      );
      await _expand(tester);
      expect(find.text('No pin found'), findsOneWidget);
      expect(find.text('Pins fell through'), findsNothing);
    });

    testWidgets('non-honored row with pin_set_size > 0 → "Pins fell through" '
        '(V2-forward-compat branch)', (tester) async {
      await tester.pumpWidget(
        _host([PinStatusBannerRow(label: 'Meal', decision: _fellThrough)]),
      );
      await _expand(tester);
      expect(find.text('Pins fell through'), findsOneWidget);
      expect(find.text('No pin found'), findsNothing);
    });

    testWidgets('mixed rows render the correct copy per row', (tester) async {
      // Scenario-4-shaped: snack honored, the rest unmatched.
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(label: 'Meal', decision: _noPinForScope),
          PinStatusBannerRow(
            label: 'Snack',
            decision: _honored(name: 'OJ + Toast'),
          ),
          PinStatusBannerRow(label: 'Top-Off', decision: _noPinForScope),
          PinStatusBannerRow(label: 'During', decision: _noPinForScope),
        ]),
      );
      await _expand(tester);

      expect(find.text('OJ + Toast'), findsOneWidget);
      // Three non-honored rows all share the same copy in V1.
      expect(find.text('No pin found'), findsNWidgets(3));
    });
  });

  group('PinStatusBanner — CTA', () {
    testWidgets('CTA reads "Pin your favorite formula" (substep 11 copy)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([PinStatusBannerRow(label: 'Meal', decision: _honored())]),
      );
      await _expand(tester);
      expect(find.text('Pin your favorite formula'), findsOneWidget);
      expect(
        find.text('Browse Formula Library'),
        findsNothing,
        reason: 'pre-substep-11 copy must not appear',
      );
    });

    testWidgets('CTA invokes onFormulaLibraryTapped callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(label: 'Meal', decision: _honored()),
        ], onCta: () => taps++),
      );
      await _expand(tester);
      await tester.tap(
        find.byKey(const ValueKey('pin_status_banner.formula_library_cta')),
      );
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('PinStatusBanner — interaction', () {
    testWidgets('starts collapsed; rows hidden until header tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([
          PinStatusBannerRow(
            label: 'Snack',
            decision: _honored(name: 'OJ + Toast'),
          ),
        ]),
      );
      // Header summary visible; row body hidden.
      expect(find.text('Using your pinned formulas'), findsOneWidget);
      expect(find.text('OJ + Toast'), findsNothing);

      await _expand(tester);
      expect(find.text('OJ + Toast'), findsOneWidget);
    });
  });

  // Onboarding (zero-pin) variant — Path 2 per substep 11 follow-up.
  // The plan has pinnable phases but the user has no pins. Banner becomes
  // a discovery prompt: collapsed by default (header only, takes minimal
  // vertical space), expand to reveal the subtext + CTA.
  group('PinStatusBanner — onboarding mode', () {
    Future<void> expandOnboarding(WidgetTester tester) async {
      await tester.tap(
        find.byKey(const ValueKey('pin_status_banner.onboarding_header')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    testWidgets('starts collapsed: header visible, subtext + CTA hidden', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [], isOnboarding: true));
      // Header always visible.
      expect(find.text('Pin formulas you love'), findsOneWidget);
      // Body hidden until tapped.
      expect(
        find.text("We'll use them whenever they fit your activity."),
        findsNothing,
      );
      expect(find.text('Pin your favorite formula'), findsNothing);
    });

    testWidgets('tapping header expands: subtext + CTA revealed', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [], isOnboarding: true));
      await expandOnboarding(tester);
      expect(
        find.text("We'll use them whenever they fit your activity."),
        findsOneWidget,
      );
      expect(find.text('Pin your favorite formula'), findsOneWidget);
    });

    testWidgets('uses the onboarding ValueKey, not the status header key', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const [], isOnboarding: true));
      expect(
        find.byKey(const ValueKey('pin_status_banner.onboarding')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pin_status_banner.header')),
        findsNothing,
        reason: 'status-mode header key must not appear in onboarding',
      );
    });

    testWidgets('does NOT render status-mode header copy', (tester) async {
      // Sanity guard: none of the three Status-mode header variants should
      // appear in onboarding mode (even after expansion).
      await tester.pumpWidget(_host(const [], isOnboarding: true));
      await expandOnboarding(tester);
      expect(find.text('Using your pinned formulas'), findsNothing);
      expect(find.text("Pin didn't apply to this workout"), findsNothing);
      expect(find.text('Some pins honored, some skipped'), findsNothing);
    });

    testWidgets('CTA invokes onFormulaLibraryTapped callback in onboarding', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(const [], isOnboarding: true, onCta: () => taps++),
      );
      await expandOnboarding(tester);
      await tester.tap(
        find.byKey(const ValueKey('pin_status_banner.formula_library_cta')),
      );
      await tester.pump();
      expect(taps, 1);
    });
  });
}
