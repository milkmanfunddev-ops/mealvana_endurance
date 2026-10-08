# 23: AI credits work as intended on develop

**Status:** in-progress — fixed, awaiting retest (wave 2, 2026-10-07)
**Labels:** fix, round:develop-2026-10, area:ai-credits
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (the backport ticket runs first, alone).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee's ruling, verbatim: "right now in develop we have tokens that start at 50 and go down to 0 i think and people can purchase token packs. just make sure that this part is working as intended. we have this for describe meal, take a photo, as well as formula kits." Once this ticket is done, develop's model holds end to end against the dev database: a new account starts at 50 whole tokens, each describe, photo and formula-kit model call costs 1 and is refused at 0 with the Out of AI credits dialog, the pill shows the real balance and moves after a spend, and a pack purchase adds its tokens. Line numbers are from code at `d49956d3`; dev schema facts are from read-only SQL on 2026-10-07.

**What is wrong today (read before the items):**
- Develop's functions count whole tokens: `ensure_free_credits` grants `AI_FREE_MONTHLY_CREDITS` (dev secret; the ledger row says 50), and `debit_credits` takes `creditCost(fn)` = 1 (`_shared/ai/credits.ts:44-53`). Enforcement is on for dev (`AI_CREDITS_ENFORCED` is set there and not on prod).
- Dev's database also carries mealplanning's micro-dollar accounting. `unit` is not in develop's migrations at all. Mealplanning's `20260922120000_ai_budget_micro_dollars.sql` (commit `a4267504`, "applied to dev") added `token_wallets.unit` and `token_ledger.unit`, converted every wallet at 20,000 usd_micro per credit, and set both column defaults to `'usd_micro'`. Before that, `20260916130000_monthly_allowance.sql` added `allowance`/`allowance_monthly`/`allowance_expires_at` and replaced `debit_credits` with an allowance-first version that keeps the same signature. On dev today all 17 wallets are `usd_micro`. 12 divide exactly by 20,000. test@test.com holds 49,897,485, so the pill's `clamp(0, 99999)` shows 99999 and never moves (02-001), while develop's +50 grant and −1 debits land in micro-dollars (02-002). There are 0 open `token_reservations`.
- Prod has no `unit` and no `allowance` column. Its `token_wallets` is not in the `supabase_realtime` publication, though dev's is.
- Nothing refreshes `CreditsController` after a spend. The pill depends on the realtime row update alone, and the functions debit in `EdgeRuntime.waitUntil` after the response is sent (`describe-meal/index.ts:242-245`, `analyze-meal-photo/index.ts:326-329`, `ai-coach/index.ts:330-333`).
- The formula kit is charged. `CoachInsightController.generate` (`coach_insight_controller.dart:65`) → `AiCoachClient.fetchInsight` → `ai-coach`, which runs the credit check (`ai-coach/index.ts:275-283`) and debits 1 (`:330-333`) only on the model path. A rule-based insight returns at `:259-272`, before the check, and costs nothing. `COACH_INSIGHTS_ENABLED` gates it **in the client only** (`app_config.dart:346-350`, default on in dev and off in prod; `formula_editor_screen.dart:126`, `:320`). The function has no gate. A 402 already reaches the dialog (`coach_insight_controller.dart:135`).
- Purchase is wired and needs no code change. The pill → `showTokenTopUpSheet`, and the dialog → `/buy-credits`. Both use the RevenueCat `credits` offering (`purchase_controller.dart:60`). `revenuecat-webhook` grants `grant_credits(… 'grant_purchase', eventId)` from `RC_PRODUCT_CREDITS` (index.ts:45-58 defaults 50/250/1; no `RC_PRODUCT_CREDITS` secret on dev), and the client polls 5 × 1.5 s (`_pollForBalanceUpdate`). Once the wallet is in tokens again, a pack's whole-token grant is correct.

1. **The dev wallets go back to whole tokens (02-001, 02-002; lead only, dev only, run once BEFORE the deploy).** Not for the agent. Develop's code stays unit-blind (decision below). The lead runs this on DEV `vlmtsdzpnjnavdgytcmi` through the Supabase MCP or the Management API, never on prod. Prod has no `unit` column, and this statement would fail there.
   ```sql
   begin;
   -- 0. stop if anything is still reserved (0 on 2026-10-07)
   do $$ begin
     if exists (select 1 from public.token_reservations where settled_at is null)
     then raise exception 'open reservations: settle them first'; end if;
   end $$;
   -- 1. wallets and ledger rows born from now on are whole tokens
   alter table public.token_wallets alter column unit set default 'credit';
   alter table public.token_ledger  alter column unit set default 'credit';
   -- 2. every usd_micro wallet back to tokens at the rate it was converted, rounded down; develop has no allowance
   with w0 as (
     select user_id, balance from public.token_wallets where unit = 'usd_micro' for update
   ), upd as (
     update public.token_wallets w
        set balance = w0.balance / 20000, allowance = 0, allowance_monthly = 0,
            allowance_expires_at = null, unit = 'credit', updated_at = now()
       from w0 where w.user_id = w0.user_id
     returning w.user_id, w0.balance as old_balance, w.balance as new_balance
   )
   insert into public.token_ledger (user_id, delta, reason, ref, balance_after, unit)
   select user_id, new_balance - old_balance, 'convert_credits',
          'usd_micro->credit@20000 develop-2026-10#23', new_balance, 'credit'
     from upd;
   commit;
   ```
   Expect 17 rows converted, test@test.com at 2,494, and `select unit, count(*) from token_wallets group by 1` showing only `credit`. Restoring the `'credit'` label is deliberate. When mealplanning's migration runs again at Phase B, its `ai_budget_convert_credits` converts exactly the wallets marked `'credit'`.
2. **The free grant is 50 in code (02-002, Lee).** `credits.ts:40` defaults `AI_FREE_MONTHLY_CREDITS` to 20. Make it 50 and rewrite the comment at `:28-39` to cite Lee's ruling of 2026-10-07 in place of the 20-credit economics. The dev secret already says 50. The lead may unset it so the code default governs, and leaves prod's secret alone (its value is unread).
3. **The debit lands before the answer (02-001).** In `describe-meal/index.ts:242-245`, `analyze-meal-photo/index.ts:326-329` and `ai-coach/index.ts:330-333`, `await debitForUsage(...)` before `jsonResponse`, in place of handing it to `waitUntil`. This makes the balance final when the client hears 200. `debitForUsage` never throws (`credits.ts:102-135`). Leave the `ai_usage`/`jade_calls` logging in `waitUntil`.
4. **The pill moves after a spend (02-001, 02-012).** `mealAiService` (`meal_ai_service.dart:74-80`) passes `MealAiService` an `onCreditsChanged` callback that runs `ref.read(creditsControllerProvider.notifier).refresh()`. `MealAiService` calls it on the 200 path of `_parseAnalysisResponse` and on both 402 branches (`:299-302`, `:353-356`) before it throws. `CoachInsightController.generate` (`coach_insight_controller.dart:82-136`) does the same after a success whose `generationSource == 'model'` and after an `InsufficientCreditsException`, but not after a rules answer. The screens stay untouched: `describe_meal_screen.dart` and `photo_capture_screen.dart` are archived by ticket 26, and `log_meal_screen.dart` / `edit_meal_log_screen.dart` already go through the service.
5. **The pill shows the real number (02-001).** In `token_pill.dart:61`, replace `value.balance.clamp(0, 99999)` with the balance floored at 0 and no upper clamp. With token wallets the number is small, and a wrong-unit wallet then reads as obviously wrong in place of a plausible 99999.
6. **A wallet in another unit is written down (D9).** Move the request handler out of `ensure-credits/index.ts:45-77` into `ensure-credits/handler.ts` (the pattern `delete-user/handler.ts` uses) so it can be tested with a fake client. After `ensure_free_credits`, read the caller's `token_wallets` row with `select('*')`. If the row has a `unit` field and it is not `'credit'`, call `captureEdgeError(..., { level: 'warning', message: '[credits] wallet not in whole tokens', extra: { userId, unit, balance } })` and still answer 200 with the balance. On prod the field is absent and nothing happens. Develop reads `unit` only here and never writes it.
7. **The Out of AI credits dialog takes its words from the content system (02-001 wall).** `insufficient_credits_paywall.dart:28-45` hardcodes the title, the fallback body, "Not now" and "Get credits", and prefers the server's English `message`. Add `ContentKeys` for the four strings in `content_keys.dart` and defaults in `assets/config/content_defaults.json`, keeping today's words. Read them through `contentServiceProvider` (the dialog's builder is a `Consumer`). Show the content body, not `error.message`. "Get credits" still pushes `/buy-credits`.

**Findings:** 02-001, 02-002 (02-012 is retested by ticket 31; 08-015 closed into ticket 12).

**Decisions:**
- Develop stays unit-blind. Its migrations have no `unit`, prod has none, and mealplanning's accounting is not designed here. The dev database is brought to develop's model by the lead's SQL (item 1), not by teaching develop to convert micro-dollars. The one unit-aware line is the D9 warning in item 6.
- Cost: once that SQL runs, mealplanning's `vana-chat` (v113 on dev, deployed 2026-10-06 12:29Z) reserves micro-dollar estimates against token wallets and is refused for any mealplanning build pointed at dev. Develop has no Vana. The clash returns if mealplanning's functions are deployed to dev again before Phase B. Phase B owns that.
- The monthly grant stays as the code has it: +50 on the first ensure of each calendar month, added on top of any balance. Lee asked for the existing model to work, not for a top-up-to-50.
- A rule-based formula-kit insight stays free. Only a model call costs 1 (flagged for Lee in the report).
- Not changed: prod's realtime publication (the refresh in item 4 and the purchase poll keep the pill honest without it), the prod `AI_FREE_MONTHLY_CREDITS` value, and the `jade-chat` cost key (ticket 27).

**Touches:** supabase/functions/_shared/ai/credits.ts, supabase/functions/_shared/ai/credits.test.ts (new), supabase/functions/ensure-credits/index.ts, supabase/functions/ensure-credits/handler.ts (new), supabase/functions/ensure-credits/handler.test.ts (new), supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, supabase/functions/ai-coach/index.ts, lib/features/ai_credits/presentation/widgets/token_pill.dart, lib/features/ai_credits/presentation/insufficient_credits_paywall.dart, lib/features/meal_logging/application/meal_ai_service.dart, lib/features/meal_logging/application/meal_ai_service.g.dart (generated), lib/features/formula_kit/application/coach_insight_controller.dart, lib/features/formula_kit/application/coach_insight_controller.g.dart (generated), lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json, test/features/ai_credits/token_pill_seam_test.dart (new), test/features/ai_credits/insufficient_credits_paywall_test.dart (new), test/features/meal_logging/meal_ai_service_credits_test.dart (new), test/features/formula_kit/coach_insight_controller_credits_test.dart (new). 20 files.

**Overlaps:** 27 (`describe-meal/index.ts`, `analyze-meal-photo/index.ts` for the `jade_calls`/`JADE_MODEL` rename; `credits.ts` if 27 drops the `jade-chat` cost). 26 does not overlap, because items 4–7 avoid the archived `describe_meal_screen.dart` and `photo_capture_screen.dart`. 29's Touches are not written yet, so the lead checks them before the wave.

Deploy (wave lead, dev): SQL first (item 1), then deploy `ensure-credits`, `describe-meal`, `analyze-meal-photo` and `ai-coach` to dev once, from the merged tree. Same names, same inputs and outputs. Agents deploy nothing.

- [x] Deno `credits.test.ts` (set `AI_CREDITS_ENFORCED=true` before a dynamic import, because `CREDITS_ENFORCED` is read at module load; fake RPC client): `FREE_MONTHLY_CREDITS` is 50 with the env unset. `describe-meal`, `analyze-meal-photo` and `ai-coach` each cost 1. Balance 0 → `allowed: false`, and `insufficientCreditsBody` is `{error:'insufficient_credits', message, balance:0, cost:1}`. `debitForUsage` sends `debit_credits(p_amount 1, p_reason 'debit_usage', p_ref fn)`. A `success:false` debit logs and does not throw.
- [x] Deno `ensure-credits/handler.test.ts`: a new user's first call answers `{balance: 50, free_monthly: 50, enforced}`. A row carrying `unit: 'usd_micro'` captures one warning and still answers 200. A row without `unit` (prod shape) captures nothing.
- [x] Seam test through the real `CreditsController` (`token_pill_seam_test.dart`): the repository is fed producer-shaped data, meaning the `ensure-credits` body exactly as the function answers it and a `token_wallets` row as PostgREST serves it on dev (`unit`, `allowance`, `allowance_monthly`, `allowance_expires_at`, `updated_at` with microseconds and `+00:00`). The pill shows 50. After `refresh()` with a row at 49, it shows 49. A row at 49,897,485 shows that number, not 99999.
- [x] `meal_ai_service_credits_test.dart`: a 200 describe answer calls `onCreditsChanged` once. A `FunctionException(402)` whose `details` is the producer 402 body above throws `InsufficientCreditsException(balance 0, cost 1)` and calls it once. A 500 does not call it.
- [x] Through the real `CoachInsightController` (`coach_insight_controller_credits_test.dart`, the write path): a model-source answer persists the insight and refreshes credits. A rules-source answer (`usage.source: 'rules'`, cost 0) refreshes nothing. A 402 leaves `AsyncError(InsufficientCreditsException)` and refreshes.
- [x] Widget test (`insufficient_credits_paywall_test.dart`): the dialog shows the content-system strings, not the server `message`, and Get credits pushes `/buy-credits`.
- [x] `flutter analyze` clean on touched files. Run codegen (the two providers change).
- [ ] Retest is ticket 12 (new account at 50, a spend moves the pill by 1, the wall at 0, a pack purchase).

Next: /testing-wave develop-2026-10 (fix wave)
