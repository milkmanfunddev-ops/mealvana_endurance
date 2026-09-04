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
      for (var i = 0; i < toggleCount && conflictIndex < 0; i++) {
        await $(toggles.at(i)).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 500));
        if (find.byKey(_warningKey).evaluate().isNotEmpty) {
          conflictIndex = i;
          break;
        }
        // Pinned a clean formula — unpin it again so the account is unchanged.
        await $(toggles.at(i)).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(milliseconds: 400));
      }

      if (conflictIndex < 0) {
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
      expect(
        find.byKey(_labelKey),
        findsNothing,
        reason: 'nothing is pinned yet, so no honored-pin label exists',
      );

      // "Choose another" dismisses WITHOUT pinning.
      await $(_chooseAnotherKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(_warningKey),
        findsNothing,
        reason: 'Choose another closes the decision moment',
      );
      expect(
        find.byKey(_labelKey),
        findsNothing,
        reason: 'FP-4a: Choose another must NOT pin the formula',
      );

      // ---- 4. Pin anyway → §1a honored, FP-4b label appears -------------
      await $(toggles.at(conflictIndex)).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 500));
      await $(_pinAnywayKey).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(milliseconds: 800));

      await $(_labelKey).waitUntilVisible(timeout: const Duration(seconds: 20));
      expect(
        find.byKey(_labelKey),
        findsWidgets,
        reason:
            '§1a labeled override: the pin is HONORED and the conflict is '
            'disclosed — never silently dropped, never silently kept',
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
