# 27: Archive Jade (the AI coach chat)

**Status:** ready (round develop-2026-10, fix)
**Labels:** fix, round:develop-2026-10, area:ai-coach
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 29 (runs first and alone). Run with 26 or after it (see Overlaps).
**Next:** `/testing-wave develop-2026-10` (fix wave)
**Model:** opus

**What to build:** Lee ruled (TRIAGE 08-001, 08-002, 08-006, 2026-10-07): comment out `/jade`, move
`lib/features/ai_coach` to `_archived`, move the shared "AI is thinking" status widget to `lib/shared/widgets`,
rename the `jade_calls` logging and the `JADE_MODEL` alias in the functions, and leave the dev-only tables. Vana
replaces the chat at Phase B. Meal logging and formula kits are not Jade and stay. Archive convention as in ticket
26: `lib/features/_archived/<feature>/<same sub-path>` (excluded at `analysis_options.yaml:14`), the route
commented out with a one-line `// ARCHIVED 2026-10-07 (round develop-2026-10, ticket 27): …` note, never deleted.
All from code at `f2e8576e`.

Inventory: `grep -rniE "ai_coach|aicoach|jade" lib test integration_test supabase docs codemagic.yaml .github`.
Every hit outside `lib/features/ai_coach/` has an action below or in "Left alone".

**App**

1. **Route (08-001, 08-002).** `lib/shared/core/app_router.dart:1055-1061` (the `MEALVANA AI COACH` header and
   the `/jade` `GoRoute`): comment out under the ARCHIVED note. Comment out import `:80`
   (`ai_coach_chat_screen.dart`). In the redirect guard, drop `currentPath == '/jade' ||` (`:134`) and the
   two comment lines that explain it (`:126-128`). Ticket 26 drops the `/meal-log/*` lines of the same
   condition. `/buy-credits` stays.
2. **Move the feature.** `git mv` these 14 files from `lib/features/ai_coach/` to `lib/features/_archived/ai_coach/`,
   keeping the sub-path. The `.g.dart` parts move with their sources, and nothing is regenerated:
   `data/ai_coach_chat_repository.dart` (+`.g.dart`), `domain/{ai_coach_message,ai_coach_conversation,ai_coach_ui_part}.dart`,
   `presentation/providers/ai_coach_banner_providers.dart` (+`.g.dart`),
   `presentation/providers/ai_coach_chat_controller.dart` (+`.g.dart`), `presentation/screens/ai_coach_chat_screen.dart`,
   `presentation/widgets/{ai_coach_choice_buttons,ai_coach_banner,ai_coach_avatar,ai_coach_meal_card}.dart`.
   Rewrite their relative imports as `package:` imports, so a later restore is a move. 08-006 (markdown markers
   in a stored reply) goes with the screen and needs no fix.
3. **The thinking-status widget.** Move `lib/features/ai_coach/presentation/widgets/ai_thinking_status.dart`
   (`AiThinkingStatus`, no provider, no `.g.dart`) to `lib/shared/widgets/ai_thinking_status.dart`. Fix its one
   relative import (`../../../../theme/kyle_design/app_text_styles.dart` → `../../theme/kyle_design/app_text_styles.dart`).
   Repoint every importer. There are **five**, not the four the ruling names: `edit_meal_log_screen.dart:19`
   is the fifth.
   - `lib/features/meal_logging/presentation/screens/log_meal_screen.dart:25`
   - `lib/features/meal_logging/presentation/widgets/meal_analysis_skeleton.dart:7`
   - `lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:19`
   - `describe_meal_screen.dart:10` and `photo_capture_screen.dart:15` (`…/meal_logging/presentation/screens/`):
     only if ticket 26 has not archived them yet. If 26 ran first, they sit in `_archived` and are left alone.
4. **Comments that name the moved code.** `lib/features/formula_kit/application/coach_insight_controller.dart:62`
   cites `ai_coach_chat_repository.dart (jade-chat edge function, HTTP 402)` as the pattern: add the
   `_archived/` path. `lib/features/meal_logging/data/meal_log_repository.dart:200-201`: `countLogsSince` was
   used only by `aiCoachHasBaselineProvider`. Its last caller is now archived. Keep the method (public, small)
   and say so in its doc comment.

**Edge functions**

5. **`jade_calls` logging becomes nothing: the `ai_usage` row already covers it.** `supabase/functions/describe-meal/index.ts:204-228`
   and `supabase/functions/analyze-meal-photo/index.ts:288-312` each insert a `jade_calls` row. Two lines later
   they write the same user, function, model and token counts to `ai_usage` through `logAiUsage`
   (`describe-meal :233`, `analyze-meal-photo :317`). `_shared/ai/usage.ts:4-9` says `ai_usage` exists on dev
   and prod, and `jade_calls` is dev-only. So on prod every describe and photo call's `jade_calls` insert fails
   and raises a `captureEdgeError` warning ("[describe-meal] Failed to log ai usage"). Whether those warnings
   reach prod Sentry is unverified. Delete both `jade_calls` blocks. Don't rename the table: the rename becomes
   one ledger, `ai_usage`. Reword `describe-meal/index.ts:137` ("credits + jade_calls/ai_usage logging" →
   "credits + ai_usage logging"). In `_shared/ai/usage.ts:4-9` and `:27`, say jade-chat is archived on the
   client and `jade_calls` is the old dev-only table no function on the meal path writes.
6. **`JADE_MODEL`: remove the alias, keep `AI_COACH_MODEL`.** `_shared/ai/model.ts:13-18` reads
   `AI_COACH_MODEL ?? JADE_MODEL ?? 'anthropic/claude-sonnet-4.6'`. Neither secret is set on dev
   (`vlmtsdzpnjnavdgytcmi`) or prod (`wvmvsodrvbkxfydabqed`): secret names listed through the Management API on
   2026-10-07, values not read. So both functions run on the default, and dropping the `JADE_MODEL` line changes
   nothing at runtime. **Nothing needs setting on dev.** Its only reader is `jade-chat`. describe-meal and
   analyze-meal-photo read `DESCRIBE_MEAL_MODEL` / `ANALYZE_MEAL_PHOTO_MODEL`, as their tests say
   (`describe-meal/index.test.ts:301-306`, `analyze-meal-photo/index.test.ts:359-364`). Delete lines 13-14 and 18.
   `AI_COACH_MODEL` keeps its name: it is not Jade-branded, and Vana at Phase B may reuse it.
7. **`jade-chat` itself, not in the ruling: left in place, flagged for the lead.** `supabase/functions/jade-chat/`
   (`index.ts`, `index.test.ts`), `_shared/ai_coach/{persona,tools,in_season}.ts` (only jade-chat imports them)
   and `_shared/ai/credits.ts:52` (`'jade-chat': 1`) stay. After this ticket the app never calls jade-chat. It
   writes the dev-only `jade_conversations` / `jade_messages` / `jade_calls` tables, which the ruling leaves
   alone. Whether to move it to `_archived/supabase/functions/` or undeploy it is the lead's call (ask Lee). No
   deploy is owed by this ticket for jade-chat. describe-meal and analyze-meal-photo are owed a dev deploy by
   the wave lead (playbook §6, overwrite in place).

**Tests and CI**

8. Delete `test/features/ai_coach/presentation/providers/ai_coach_chat_controller_test.dart` (the only file there;
   it tests only archived code).
9. `test/seeded_tests/meal_weather_ai_coach_content_test.dart`: delete group 5 `AiCoachChatScreen — seeded
   message history` (`:1115-~1190`), the `_FakeAiCoachChatRepository` fake (`:138-~160`), the five ai_coach
   imports (`:25-29`) and header lines `:1`, `:11`. Ticket 26 edits groups 1, 1b and 2 of the same file.
10. `test/smoke_tests/auth_misc_smoke_test.dart`: delete the `AiCoachChatScreen builds` block (`:214-~225`), the
    `_FakeAiCoachChatController` (`:93-100`), imports `:48-49` and the header mentions `:5`, `:17`. Ticket 26
    edits the Recipes and Share blocks of the same file.
11. `integration_test/flows/ai_coach_chat_flow_test.dart` → `_archived/integration_test/flows/` (that root archive
    folder exists and is analysis-excluded). Then remove the `'ai_coach_chat_flow_test'` entry from
    `_mustNeverAutoRun` in `test/shared/ci_config_contract_test.dart:36-37`. Its "every named flow exists" test
    (`:354-370`) would otherwise fail on the missing file. Leave `codemagic.yaml:1520`, `:1620` and
    `.github/workflows/tests-selfhosted.yml:224` untouched. They are comments, the same contract test polices
    `codemagic.yaml`'s comment placement (`:511`), and a Codemagic diff isn't worth a stale comment line.
    Update `integration_test/README.md:72`, `:111`, `:149`, which still say `jade_chat_flow_test`: the flow is
    archived.
12. Tests that stay green unchanged: `test/features/meal_logging/meal_logging_business_logic_test.dart:523-524`
    and `test/features/home_shell/home_shell_calendar_seam_test.dart:101-118` (stored `jade_baseline` source),
    and `test/features/formula_kit/data/ai_coach_client_test.dart` (formula kit).

**Left alone (stored data, other features, history)**
- `MealLogSource.aiCoachBaseline('jade_baseline')` (`meal_log_source.dart:4`, `:26`), the Drift column comment
  `meal_logs_table.dart:34`, `app_database.dart:231-233`, `recipes_table.dart:6`, `saved_meals_table.dart:7`,
  `meal_logs_table.dart:8`, `home_shell_calendar_assembler.dart:21`: stored values and schema notes.
- `preferences_service.dart:94-105` (`jade_baseline_tip_dismissed`): an on-device key. The getter and setter
  lose their only caller (the banner). Leave them, so the key isn't orphaned silently.
- Formula kit: `lib/features/formula_kit/data/ai_coach_client.dart` (+`.g.dart`) calls the `ai-coach` edge
  function (coach insights), which has nothing to do with Jade. Keep it. The name misleads; a rename to
  something like `coach_insight_client.dart` is a later ticket.
- The dev-only tables `jade_conversations`, `jade_messages`, `jade_calls` and `docs/database/meal_logging_jade_schema.sql`.
- Docs: `docs/deployment/README.md:74` (jade-chat entry): append "(no app caller since 2026-10-07, client
  archived in round develop-2026-10)". Everything else stays: `docs/_archived/**`, `docs/ssot/**` renderings,
  `docs/dev_schema.txt`, `docs/prod_schema.txt`, `docs/database/apply_all.sql`, `docs/features/**`,
  `docs/release/**`, `docs/test/**`, `docs/daily/**`, `supabase/functions/EDGE_FUNCTION_AUDIT.md:38`,
  `supabase/migrations/_archived/…ai_usage_token_ledger.sql`, and `docs/testing-wave/COVERAGE.md:33` (lead's
  ledger).

**Findings:** 08-001, 08-002, 08-006.

**Decisions:** Lee, 2026-10-07 (TRIAGE). The ticket decides two details the ruling left open: the
`jade_calls` "rename" is deletion of the duplicate insert, since `ai_usage` already holds the row (item 5), and
`JADE_MODEL` is dropped, with no secret to set (item 6). The jade-chat function is left for the lead (item 7).

**Touches:** lib/shared/core/app_router.dart; lib/features/ai_coach/** (14 files moved to
lib/features/_archived/ai_coach/**, including ai_coach_chat_repository.g.dart, ai_coach_chat_controller.g.dart,
ai_coach_banner_providers.g.dart); lib/features/ai_coach/presentation/widgets/ai_thinking_status.dart →
lib/shared/widgets/ai_thinking_status.dart; lib/features/meal_logging/presentation/screens/{log_meal_screen.dart,edit_meal_log_screen.dart};
lib/features/meal_logging/presentation/widgets/meal_analysis_skeleton.dart;
(only if 26 has not run) lib/features/meal_logging/presentation/screens/{describe_meal_screen.dart,photo_capture_screen.dart};
lib/features/formula_kit/application/coach_insight_controller.dart (comment);
lib/features/meal_logging/data/meal_log_repository.dart (comment);
supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts,
supabase/functions/_shared/ai/usage.ts (comments), supabase/functions/_shared/ai/model.ts;
test/features/ai_coach/presentation/providers/ai_coach_chat_controller_test.dart (deleted);
test/seeded_tests/meal_weather_ai_coach_content_test.dart, test/smoke_tests/auth_misc_smoke_test.dart,
test/shared/ci_config_contract_test.dart; integration_test/flows/ai_coach_chat_flow_test.dart →
_archived/integration_test/flows/; integration_test/README.md; docs/deployment/README.md.

**Overlaps:** 26 (`app_router.dart`: the guard condition at `:132-135` and the import and route blocks;
`meal_weather_ai_coach_content_test.dart`; `auth_misc_smoke_test.dart`; `describe_meal_screen.dart`,
`photo_capture_screen.dart`). The lead runs 26 and 27 in one agent, or 26 then 27. 23 (`supabase/functions/describe-meal/index.ts`,
`analyze-meal-photo/index.ts`, in 23's Touches. `credits.ts` is not touched here). 24 (`edit_meal_log_screen.dart`,
one import line here). 29 (`app_router.dart`, `log_meal_screen.dart`, `edit_meal_log_screen.dart`,
`meal_weather_ai_coach_content_test.dart`). 29 runs first. Re-read line numbers after it lands.

- [ ] `grep -rn "features/ai_coach/" lib test integration_test` returns nothing outside `lib/features/_archived/`.
      `grep -rn "jade_calls\|JADE_MODEL" supabase/functions --include=*.ts` hits only `jade-chat/` and the
      usage.ts history comment.
- [ ] Deno: `deno test --allow-all --allow-sys supabase/functions/describe-meal supabase/functions/analyze-meal-photo`
      green. Add one assertion to each `index.test.ts` that the function source no longer contains
      `"jade_calls"` (a source read, like the existing env-wiring checks at `:301` and `:359`).
- [ ] `flutter analyze` clean. Codegen is not needed: no annotation changes, and the `.g.dart` files move with
      their parts.
- [ ] `test/shared/ci_config_contract_test.dart`, the edited seeded and smoke files, and
      `test/features/meal_logging/` green.
- [ ] Wave lead: deploy describe-meal and analyze-meal-photo to dev, then one Describe call (ticket 31's
      retest). `query_logs` (ticket 25's SQL) shows no "Failed to log ai usage" line, and `ai_usage` has the row.
