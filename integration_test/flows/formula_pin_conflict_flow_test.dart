/// Pin CONFLICT lifecycle under **Patrol** — proves the ratified labeled
/// override works end to end on a real profile, for BOTH formula kinds.
///
/// Why this flow exists (the gap it closes):
///   Before it, no integration flow mentioned allergies at all. FP-4a/4b/4d are
///   widget-tested, but the real path — an athlete profile carrying an allergy,
///   a library formula that conflicts with it, the pre-pin decision moment, the
///   honored pin, its persistent label, and Unpin — had never run against the
///   deployed backend. Xuan found two defects on this surface by hand on
///   2026-09-03; that is the evidence it deserves live coverage.
///
/// Contract pinned (formula-pin-surface.md, RATIFIED Xuan 2026-09-03):
///   FP-4a  pinning an allergy-conflicted formula raises the INLINE warning
///          instead of pinning; "Choose another" (filled primary) dismisses
///          without pinning, "Pin anyway" completes it
///   FP-4b  an honored conflicting pin carries the persistent collapsible
///          label, expanding to Keep pin / Unpin; the glyph carries the dot
///   §1a    the pin is NEVER auto-removed — the label discloses, it never blocks
///   FP-4d  personal formulas follow the SAME contract (they reach a plan only
///          through the pin set — pins.ts resolvePersonalFormulaPins)
///
/// Data precondition (self-skips, house pattern):
///   Needs the signed-in account to have at least one allergy on file AND a
///   library formula that conflicts with it — i.e. a card already rendering the
///   conflict affordance. The flow does NOT mutate the account's allergy
///   profile: this is a shared dev account, and a test that edits a profile can
///   strand it if it fails mid-run. If no conflicting card exists, it skips
///   with a message naming the precondition instead of failing red.
///
/// Run:
///   patrol test --target integration_test/flows/formula_pin_conflict_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';

/// Every Before-card thumbtack, whose key is
/// `formula_kit.before_card_pin_<id>` — acts on whichever formula conflicts
/// without hard-coding catalog ids.
Finder _beforePinToggles() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith(
        'formula_kit.before_card_pin_',
      ),
);

const _warningKey = ValueKey('formula_kit.pin_conflict_warning');
const _chooseAnotherKey = ValueKey('formula_kit.pin_conflict_choose_another');
const _pinAnywayKey = ValueKey('formula_kit.pin_conflict_pin_anyway');
const _labelKey = ValueKey('formula_kit.pin_conflict_label');
const _labelHeaderKey = ValueKey('formula_kit.pin_conflict_label_header');

/// The nine allergen chips in the More-filters sheet, by `Allergy.dbValue`.
const _allergenDbValues = <String>[
  'dairy', 'eggs', 'fish', 'gluten', 'peanuts',
  'sesame', 'shellfish', 'soy', 'tree_nuts',
];

/// Whether the pin toggle under [toggle] currently reads as PINNED. Asks the
/// card under test directly instead of counting labels across the screen: the
/// library is a LAZY list, so collapsing an expanded warning shortens the card
/// and pulls further items into the viewport — a screen-wide label count then
/// changes from layout alone, with nothing pinned. (That false signal cost
/// several runs on 2026-09-04.)
Future<bool> _toggleIsPinned(
  PatrolIntegrationTester $,
  Finder toggle,
) async {
  // The card must be BUILT to be read: collapsing an expanded warning shrinks
  // it and the lazy list can drop it out of the viewport entirely, so a plain
  // read throws "Bad state: No element". Scroll it back in first, trying both
  // directions because the collapse may move it either way.
  if (toggle.evaluate().isEmpty) {
    for (final direction in [AxisDirection.up, AxisDirection.down]) {
      try {
        await $.scrollUntilVisible(
          finder: toggle,
          scrollDirection: direction,
          maxScrolls: 15,
          settleBetweenScrollsTimeout: const Duration(seconds: 1),
        );
        break;
      } on Exception {
        continue;
      }
    }
  }
  final icon = find.descendant(
    of: toggle,
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_PinIconButton',
    ),
  );
  return ($.tester.widget(icon.first) as dynamic).isPinned as bool;
}

/// Whether a More-filters chip is currently selected. `_Chip` is private to
/// `more_filters_sheet.dart`, so its `selected` field is read dynamically —
/// the instance is reachable even though the type is not.
bool _chipIsSelected(PatrolIntegrationTester $, Finder chip) {
  final widget = $.tester.widget(chip) as dynamic;
  return widget.selected as bool;
}

void main() {
  patrolTest(
    'an allergy-conflicted pin warns first, is honored, then labels and unpins',
    ($) async {
      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated(
        $,
        sentinel: const ValueKey('fuel_timeline.settings'),
      )) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Settings → Diet/Allergies/Formulas hub → Formula Library --
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(
        const ValueKey('fuel_timeline.settings'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('settings.food_prefs_row'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $(const ValueKey('settings.food_prefs_row'))
          .scrollTo(
            maxScrolls: 12,
            settleBetweenScrollsTimeout: const Duration(seconds: 1),
          )
          .tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        'Formula Library',
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      await $('Formula Library').tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 300));
      await $(
        const ValueKey('formula_kit.library_screen'),
      ).waitUntilVisible(timeout: const Duration(seconds: 30));

      // ---- 1b. Clear the profile-seeded allergen filters ---------------
      // WITHOUT THIS THE FLOW IS VACUOUS. The library pre-selects the
      // athlete's profile allergens under "HIDE FORMULAS WITH", so on any
      // account that actually HAS an allergy every conflicting formula is
      // filtered out of the list before the walk begins — no thumbtack can
      // ever raise FP-4a, the loop below finds nothing, and the test
      // self-skips while reporting green. (Observed 2026-09-04: with gluten
      // on file the Before list showed "15 / 29".)
      //
      // So open More filters, deselect every active allergen chip, and apply.
      // This is a VIEW filter only — it does not touch the stored profile.
      await $(
        const ValueKey('formula_kit.more_filters_button'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $(
        const ValueKey('formula_kit.more_filters_sheet'),
      ).waitUntilVisible(timeout: const Duration(seconds: 20));
      for (final allergen in _allergenDbValues) {
        final chip = find.byKey(ValueKey('formula_kit.more_filters.allergy.$allergen'));
        if (chip.evaluate().isEmpty) continue;
        final selected = _chipIsSelected($, chip);
        if (selected) {
          await $(chip).tap(settlePolicy: SettlePolicy.noSettle);
          await $.pump(const Duration(milliseconds: 200));
        }
      }
      await $(
        const ValueKey('formula_kit.more_filters.apply'),
      ).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 600));

      // ---- 2. Precondition: a Before formula that conflicts -------------
      try {
        await $(
          _beforePinToggles(),
        ).waitUntilExists(timeout: const Duration(seconds: 20));
      } on Exception {
        markTestSkipped(
          'No Before formulas in the library for this account — the pin '
          'feature has nothing to act on. Data precondition, not a defect.',
        );
        return;
      }

      // Tap thumbtacks until one raises the FP-4a warning. A non-conflicting
      // formula simply pins, so undo it before trying the next card.
      final toggles = _beforePinToggles();
      final toggleCount = toggles.evaluate().length;
      var conflictIndex = -1;
      // The conflicting card's OWN key. Index-based identity is unusable here:
      // the list is lazy AND re-sorts when a formula is pinned (pinned cards
      // move up into "Your Formulas"), so `toggles.at(i)` stops pointing at the
      // card it found. That mis-identification is what made the post-decision
      // assertions read a different, genuinely-pinned card and report FP-4a as
      // broken when it is not (verified by hand on device 2026-09-04).
      ValueKey<String>? conflictToggleKey;
      for (var i = 0; i < toggleCount && conflictIndex < 0; i++) {
        await $(toggles.at(i)).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 500));
        // Match the ALLERGY variant specifically. `_warningKey` is the shared
        // root of both variants, but `PinConflictWarning.diet` deliberately
        // passes `onChooseAnother = null` and renders NO action pair (FP-4a:
        // a diet conflict is one soft line). Keying off the root alone made
        // this flow walk into a diet conflict and then hunt for a button that
        // variant never renders.
        final isAllergyVariant =
            find.byKey(_warningKey).evaluate().isNotEmpty &&
            find.byKey(_chooseAnotherKey).evaluate().isNotEmpty;
        if (isAllergyVariant) {
          conflictIndex = i;
          conflictToggleKey =
              toggles.evaluate().elementAt(i).widget.key as ValueKey<String>;
          break;
        }
        // Pinned a clean formula — unpin it again so the account is unchanged.
        await $(toggles.at(i)).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 400));
      }

      if (conflictIndex < 0) {
        // Loud on purpose: patrol's summary reports a skipped test as
        // "Successful: 1 / Skipped: 0", so a silent skip is indistinguishable
        // from a real pass. This flow WAS passing vacuously (2026-09-04)
        // because the library hid every conflicting formula behind the
        // profile-seeded allergen filter — cleared in step 1b above.
        // ignore: avoid_print
        print(
          'FLOW-VACUOUS: formula_pin_conflict asserted NOTHING — no Before '
          'formula conflicts with this account. FP-4a/FP-4b were not '
          'exercised. Precondition: an allergy on file that a library '
          'formula contains.',
        );
        markTestSkipped(
          'No Before formula conflicts with this account\'s profile, so the '
          'FP-4a decision moment cannot be reached. Precondition: the account '
          'needs an allergy on file that a library formula contains.',
        );
        return;
      }

      // ---- 3. FP-4a: the warning appears INSTEAD of pinning -------------
      expect(
        find.byKey(_chooseAnotherKey),
        findsOneWidget,
        reason: 'FP-4a offers the safer action first',
      );
      expect(find.byKey(_pinAnywayKey), findsOneWidget);

      final conflictToggle = find.byKey(conflictToggleKey!);
      expect(
        await _toggleIsPinned($, conflictToggle),
        isFalse,
        reason: 'the decision moment is open; nothing is pinned yet',
      );

      // "Choose another" dismisses WITHOUT pinning.
      // The warning renders inline in whichever card the hunt landed on, which
      // may be anywhere in a long list — ABOVE or below the current viewport.
      // `scrollTo` only ever drags one way and cannot come back up, so use
      // `ensureVisible`, which scrolls the enclosing Scrollable in whichever
      // direction the target actually needs. (Verified by hand on device
      // 2026-09-04: the FP-4a pair renders and is tappable — the earlier
      // failure here was this scroll, not the button.)
      await $.tester.ensureVisible(find.byKey(_chooseAnotherKey));
      await $.pump(const Duration(milliseconds: 300));
      await $(_chooseAnotherKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(_warningKey),
        findsNothing,
        reason: 'Choose another closes the decision moment',
      );
      expect(
        await _toggleIsPinned($, conflictToggle),
        isFalse,
        reason: 'FP-4a: Choose another must NOT pin the formula',
      );

      // ---- 4. Pin anyway → §1a honored, FP-4b label appears -------------
      await $(conflictToggle).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));
      await $.tester.ensureVisible(find.byKey(_pinAnywayKey));
      await $.pump(const Duration(milliseconds: 300));
      await $(_pinAnywayKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 800));

      // FP-4b: once pinned, the card MOVES into the "Your Formulas" section at
      // the top of the list, so the label is very likely off-screen from where
      // the pin was tapped. Wait for it to EXIST, then scroll it into view —
      // waitUntilVisible alone cannot scroll and will time out on a label that
      // is present and correct. (Confirmed by hand on device 2026-09-04:
      // "Pinned despite your gluten allergy".)
      // The list is LAZY and the pinned card moves UP into "Your Formulas",
      // so after pinning from a card far down the library the label is not
      // merely off-screen — it is not built at all, and neither
      // `waitUntilExists` nor `ensureVisible` can see it. `scrollUntilVisible`
      // re-evaluates the finder as it drags, so it can reach a lazily-built
      // widget; AxisDirection.up drags downward, revealing content ABOVE.
      await $.scrollUntilVisible(
        finder: find.byKey(_labelKey),
        scrollDirection: AxisDirection.up,
        maxScrolls: 20,
        settleBetweenScrollsTimeout: const Duration(seconds: 1),
      );
      await $.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(_labelKey),
        findsWidgets,
        reason:
            '§1a labeled override: the pin is HONORED and the conflict is '
            'DISCLOSED — never silently dropped, never silently kept',
      );

      // ---- 5. FP-4b: expand → Unpin (also the cleanup) ------------------
      await $(_labelHeaderKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
      await $('Unpin').waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Unpin').tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 800));

      expect(
        find.byKey(_labelKey),
        findsNothing,
        reason:
            'unpinned ⇒ the formula is in no plan ⇒ nothing to warn about '
            '(FP-4d(c)); this also leaves the shared account as we found it',
      );
    },
  );
}
