/// Meal-plan build under **Patrol** — the whole Vana loop end to end, ending
/// in a row that actually exists in Supabase:
///
///   Food tab → New meal plan → Vana's opener → pick meals from the carousel
///   → primary picker chip → the plan appears on the Plan tab → Confirm →
///   the Shopping tab lists items → "Ate it" on a plan tile → a `meal_logs`
///   row with `plan_meal_id` set.
///
/// **The assertion that matters is the last one.** Every earlier step is UI
/// state; `log_from_plan` is the only place the planner writes into the
/// athlete's food diary, and the probe reads that row back through PostgREST
/// as the test user (`docs/implement_mealplanning/07-verification-release.md`).
///
/// **Dev only.** The opener and every picker turn call `vana-chat` /
/// `vana-action`, so this burns model spend — it self-skips on prod, the same
/// rule `ai_coach_chat_flow_test.dart` follows.
///
/// **Self-skips, not failures**, when a precondition the flow cannot create
/// is missing: no credentials, no Food tab (this build's Pro gate is on and
/// the tester is not entitled), or Vana never returns a picker within the
/// budget (a model/rate-limit outage is not a client regression). Everything
/// after a precondition is met is a hard assertion.
///
/// Provider-free (no Garmin/TrainingPeaks credentials), so it runs on iOS and
/// Android.
///
/// Run (dev only):
///   patrol test --target integration_test/flows/meal_plan_build_flow_test.dart \
///     --flavor dev \
///     --dart-define-from-file=.env.dev.local \
///     --dart-define-from-file=secrets/integration_test.env \
///     --device "iPhone 17 Pro"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../helpers/flow_launcher.dart';
import '../helpers/supabase_probe.dart';
import '../helpers/test_config.dart';

const _foodTab = ValueKey('bottom_nav.food_tab');
const _foodScreen = ValueKey('meal_planning.food_screen');
const _tabPlan = ValueKey('meal_planning.tab_plan');
const _tabShopping = ValueKey('meal_planning.tab_shopping');
const _newPlan = ValueKey('meal_planning.btn_new_plan');
const _chatScreen = ValueKey('meal_planning.vana_chat_screen');
const _confirm = ValueKey('meal_planning.btn_confirm');
const _ateIt = ValueKey('meal_planning.tile_sheet.ate_it');
const _shoppingEmpty = ValueKey('meal_planning.shopping_empty');

/// Meal cards inside a picker carousel turn.
Finder _pickerCards() => _keysStartingWith('meal_planning.picker_card_');

/// Rows of the confirmed/draft plan on the Plan tab.
Finder _planTiles() => _keysStartingWith('meal_planning.plan_tile_');

/// Picker chips ("I like these" / "Next: Dinner" / "That's my week").
Finder _pickerChips() => _keysStartingWith('meal_planning.picker_chip_');

/// Aisle rows on the Shopping tab.
Finder _shoppingRows() => _keysStartingWith('meal_planning.shopping_check_');

Finder _keysStartingWith(String prefix) => find.byWidgetPredicate((w) {
  final key = w.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

/// Pumps in 500 ms steps until [finder] matches at least [atLeast] widgets, or
/// [timeout] elapses. Returns whether it matched.
///
/// Deliberately NOT pumpAndSettle: a Vana turn streams, so there is almost
/// always an animation or a pending frame in flight and settle would time out
/// on a perfectly healthy screen.
Future<bool> _waitFor(
  PatrolIntegrationTester $,
  Finder finder, {
  int atLeast = 1,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final polls = timeout.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
    await $.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().length >= atLeast) return true;
  }
  return false;
}

/// Inverse of [_waitFor]: pumps until [finder] matches nothing.
Future<bool> _waitUntilGone(
  PatrolIntegrationTester $,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final polls = timeout.inMilliseconds ~/ 500;
  for (var i = 0; i < polls; i++) {
    await $.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isEmpty) return true;
  }
  return false;
}

void main() {
  patrolTest(
    'build a meal plan with Vana, confirm it, and log a meal from the plan',
    ($) async {
      if (TestConfig.isProd) {
        markTestSkipped(
          'Every turn of this flow calls the vana-chat / vana-action edge '
          'functions — skipped on prod to avoid burning real AI spend.',
        );
        return;
      }

      await launchApp();
      await $.pump(const Duration(milliseconds: 500));

      if (!await ensureAuthenticated($)) {
        markTestSkipped(noAuthSkipMessage());
        return;
      }

      // ---- 1. Food tab -------------------------------------------------
      if (!$(_foodTab).exists) {
        markTestSkipped(
          'No Food tab: this build has PRO_GATE_ENABLED=true and the tester '
          'has no active Pro entitlement. The gate itself is covered by '
          'pro_gate_flow_test.dart.',
        );
        return;
      }
      await $(_foodTab).tap(settlePolicy: SettlePolicy.noSettle);
      expect(
        await _waitFor(
          $,
          find.byKey(_foodScreen),
          timeout: const Duration(seconds: 25),
        ),
        isTrue,
        reason: 'The Food tab must open the Food screen.',
      );
      await $(_tabPlan).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(seconds: 2));

      // ---- 2. Build a plan, unless one is already there -----------------
      //
      // The tester account is shared across the bundle and across runs, so a
      // plan may already exist. Building a second one is not a better test —
      // what follows (confirm, shopping, log) is identical either way — and
      // it doubles the model spend, so the chat leg is skipped when the Plan
      // tab already has tiles.
      if (_planTiles().evaluate().isEmpty) {
        expect(
          $(_newPlan).exists,
          isTrue,
          reason:
              'An empty Plan tab must offer "New meal plan" — without it there '
              'is no way into the planner.',
        );
        await $(_newPlan).tap(settlePolicy: SettlePolicy.noSettle);

        expect(
          await _waitFor(
            $,
            find.byKey(_chatScreen),
            timeout: const Duration(seconds: 25),
          ),
          isTrue,
          reason: '"New meal plan" must open the Vana chat.',
        );

        // Vana's opener: a sentence plus a picker carousel. Generous budget —
        // this is a cold model call behind an edge function.
        if (!await _waitFor(
          $,
          _pickerCards(),
          timeout: const Duration(minutes: 2),
        )) {
          markTestSkipped(
            'Vana returned no meal picker within 2 minutes — a model or '
            'rate-limit outage, not a client regression. The parsing of every '
            'part kind is pinned by the frozen fixtures in '
            'test/features/meal_planning/.',
          );
          return;
        }

        // Tick up to two meals from the carousel.
        final cards = _pickerCards().evaluate().toList();
        final picks = cards.length < 2 ? cards.length : 2;
        for (var i = 0; i < picks; i++) {
          await $(
            _pickerCards().at(i),
          ).tap(settlePolicy: SettlePolicy.noSettle);
          await $.pump(const Duration(milliseconds: 800));
        }

        // The primary chip commits the picks ("I like these" / "Next: …" /
        // "That's my week", depending on coverage).
        expect(
          await _waitFor(
            $,
            _pickerChips(),
            timeout: const Duration(seconds: 30),
          ),
          isTrue,
          reason: 'A picker turn must offer its chips.',
        );
        await $(_pickerChips().first).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(seconds: 3));

        // Back to the Food tab; the plan is on the Plan tab, not in the chat.
        await $(_foodTab).tap(settlePolicy: SettlePolicy.noSettle);
        await $.pump(const Duration(seconds: 2));
        if ($(_tabPlan).exists) {
          await $(_tabPlan).tap(settlePolicy: SettlePolicy.noSettle);
        }
      }

      // ---- 3. The plan renders -----------------------------------------
      expect(
        await _waitFor($, _planTiles(), timeout: const Duration(seconds: 60)),
        isTrue,
        reason:
            'After picking meals the Plan tab must list them — this is the '
            'local Drift watch reflecting the server batch.',
      );

      // ---- 4. Confirm (draft plans only) -------------------------------
      if ($(_confirm).exists) {
        await $(_confirm).tap(settlePolicy: SettlePolicy.noSettle);
        // confirm_plan is remote-ack: the button is only gone once the plan
        // has come back confirmed, so its disappearance IS the ack.
        expect(
          await _waitUntilGone(
            $,
            find.byKey(_confirm),
            timeout: const Duration(seconds: 45),
          ),
          isTrue,
          reason:
              'Confirm must disappear once the server acks the confirmed plan; '
              'a button that stays is an unacked (or failed) confirm.',
        );
        await $.pump(const Duration(seconds: 2));
      }

      // ---- 5. Shopping tab ---------------------------------------------
      await $(_tabShopping).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(seconds: 2));
      final hasRows = await _waitFor(
        $,
        _shoppingRows(),
        timeout: const Duration(seconds: 30),
      );
      expect(
        hasRows || $(_shoppingEmpty).exists,
        isTrue,
        reason:
            'The Shopping tab must render either its aisle rows or its empty '
            'state — a blank tab means the controller threw.',
      );
      if (!hasRows) {
        // A confirmed plan whose meals carry no ingredients (assembly-only
        // week) legitimately produces an empty list; say so rather than fail.
        debugPrint(
          'Shopping list is empty for this plan — no ingredient rows to assert.',
        );
      }

      // ---- 6. "Ate it" → a real meal_logs row ---------------------------
      await $(_tabPlan).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(seconds: 2));
      expect(
        await _waitFor($, _planTiles(), timeout: const Duration(seconds: 30)),
        isTrue,
        reason: 'The Plan tab must still list the plan after confirming.',
      );

      final probe = await SupabaseProbe.signIn();
      final before = probe == null ? const [] : await _planMealLogs(probe);

      await $(_planTiles().first).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(seconds: 1));

      if (!$(_ateIt).exists) {
        markTestSkipped(
          'The tile sheet offers no "Ate it": every serving of this plan meal '
          'is already logged (servingsLeft == 0). Re-run against a fresh plan.',
        );
        return;
      }
      await $(_ateIt).tap(settlePolicy: SettlePolicy.noSettle);
      await $.pump(const Duration(seconds: 5));

      if (probe == null) {
        markTestSkipped(
          'No Supabase probe session (INTEGRATION_TEST credentials absent) — '
          'the UI leg passed but the meal_logs row could not be verified.',
        );
        return;
      }

      // Poll: log_from_plan is remote-ack, but PostgREST may lag the ack by a
      // beat.
      List<Map<String, dynamic>> after = const [];
      for (var i = 0; i < 10; i++) {
        after = await _planMealLogs(probe);
        if (after.length > before.length) break;
        await $.pump(const Duration(seconds: 2));
      }

      expect(
        after.length,
        greaterThan(before.length),
        reason:
            '"Ate it" must write a meal_logs row with plan_meal_id set — that '
            'row IS the plan→diary bridge, and no widget assertion can see it.',
      );
      expect(
        after.first['plan_meal_id'],
        isNotNull,
        reason: 'The new meal_logs row must carry its plan_meal_id.',
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

/// This athlete's meal logs that came from a plan, newest first.
Future<List<Map<String, dynamic>>> _planMealLogs(SupabaseProbe probe) =>
    probe.select(
      'meal_logs',
      query:
          'user_id=eq.${probe.userId}'
          '&plan_meal_id=not.is.null'
          '&select=id,name,plan_meal_id,created_at'
          '&order=created_at.desc',
    );
