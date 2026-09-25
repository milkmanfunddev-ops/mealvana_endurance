> **RESOLVED 2026-09-20 → A1+B1 — flag observation-only, gates attempt-and-observe; scope request drafted (Gmail thread 19c25325bd4b2d71)**

type: spec-erratum
bundle: data-integrations@v1 (Q-INT26 item 4 + the provider_is_premium capture) → remediation via corpus bundle / @v1.1 scope call

## Why this matters
Three app behaviors gate on TP's `IsPremium` flag, and the flag is now PROVEN unreliable —
one ratified capture rung can never execute behind it, and write-back can be wrongly
blocked for athletes whose accounts actually carry premium features.

## The evidence (live, 2026-09-18 — `runs/2026-09-18-tp-premium-trial-probe.md`)
1. **The flag misreads premium-featured accounts.** Athlete `6635555` has active premium
   trial features (future planning unlocked; populated `IFPlanned`/`TssPlanned` on the
   wire) and `/v1/athlete/profile` returns `IsPremium: false` for it.
2. **The stored flag is null for nearly everyone.** `provider_is_premium` census
   (`scripts/query-ledger.sh integrations all`, count-only): prod **0 true / 2 false /
   9 null**; dev **0 true / 0 false / 7 null**. Captured only at CONNECT (migration
   2026-09-11; `training_peaks_oauth_service.dart:175`), never backfilled, never
   re-captured — so tier changes (trial start/expiry, upgrades) are invisible forever.
3. **`/v2/metrics` is refused by SCOPE, not tier.** 401 on tokens that had 200'd on
   `/v2/workouts` seconds earlier, on BOTH athletes probed. The client comment
   (`training_peaks_api_client.dart:470`) models "a 403 for basic athletes"; the wire
   gives 401-for-everyone — our OAuth grant lacks `metrics:read`.

## The three gates keyed on the flag
| Site | Behavior | Consequence of the evidence |
|---|---|---|
| `training_peaks_sync_service.dart:757` `_fetchMetricsIfStale` | returns unless `providerIsPremium == true` | With **zero true rows ever** in either environment, this fetch has NEVER run for any athlete — and behind the gate the call is scope-refused anyway. **Q-INT26 item 4 (body metrics) is double-dead**: the gate never opens, and the endpoint is unfetchable under the current grant. Second ratified capture rung that has never executed (first: §7.1 TSS/hr). |
| `tp_writeback_service.dart:110` `refreshPremiumEligibility` | `IsPremium=false` ⇒ `setTpWritebackPremiumBlocked(true)` | A premium-featured trial athlete reads false ⇒ write-back proactively blocked for an account that may accept it. Whether TP actually rejects trial write-backs is UNOBSERVED — the flag decides without evidence either way. |
| `tp_writeback_service.dart:577` (403 handler) | 403 + flag false ⇒ permanent block | Compounded by (1): the confirmation step consults the same unreliable flag. |

## Where the defect is NOT
The capture of the flag itself is harmless as an OBSERVATION (a connect-time snapshot is
still a fact). The defect is every place the snapshot is treated as the athlete's current
tier, and the ratified comment "IsPremium predicts null" (Q-INT26) — falsified: exposure
tracks account STATE, and the flag does not track account state.

## The smallest correction
1. **Q-INT26 item 4 footnote:** body-metrics capture is *unfetchable under the current
   OAuth grant* (`metrics:read` refused, evidence 2026-09-18) — either request the scope
   from TP (provider relations) or mark the item NOT-FETCHABLE; the `IsPremium` gate in
   front of it is dead code either way.
2. **Re-document `provider_is_premium`:** "connect-time snapshot; false-negative on
   premium-featured trials; null for pre-2026-09-11 connections; NEVER a behavioral
   predicate." Migration comment `20260911150000…sql:24` ("predicts null completed") needs
   the same correction.
3. **Behavioral gates → attempt-and-observe:** the write-back eligibility block should key
   on TP's actual response to a write-back attempt, not on the flag (the 403 handler
   already half-does this; the proactive block at `:110` does not).
4. **DI-13c corollary:** a gate keyed on a captured flag needs a proven-true twin before
   it may block behavior. `provider_is_premium` has zero observed true values anywhere.

## Open question (needs Xuan, not decided here)
Keep the flag as observation only / re-capture per sync / drop the column — and whether to
ask TP for `metrics:read` + file-export scopes in one provider-relations request (the
same grant limitation now blocks two ratified items: Q-INT26 item 4 and Q-INT29's C1 route).

---

**Ops cross-reference (2026-09-18, later):** the write-back gate is filed app-side as
`ops/data/bug-reports/2026-09-18-trainingpeaks-writeback-blocked-by-unreliable-ispremium-flag.md`
(ops main `2a28e4c`), with the unobserved question — would TP accept a trial athlete's
write-back at all — first in its investigation list. The body-metrics gate is deliberately
NOT a separate ops bug (scope-refused behind it, no app-side change can fix it); it lives
as a sibling finding inside that report and stays spec-side here. If Xuan rules to request
`metrics:read` from TP, the app-side row gets split out then.
