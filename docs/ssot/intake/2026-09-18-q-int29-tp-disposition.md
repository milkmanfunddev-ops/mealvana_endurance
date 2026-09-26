> **RESOLVED 2026-09-20 → Q-INT29 narrowed — option A; register entry + §7.3/§1.6 notes**

type: ruling-request
bundle: data-integrations@v1 (Q-INT29, RULED 2026-09-17) → disposition consumed by the corpus bundle and the @v1.1 successor

## Why this matters
Q-INT29 ("persist structure-parsed zone splits") is a ratified ruling whose TP input is now
proven unreachable — leaving it undispositioned means a ruled clause with no demonstrable
input stays on the books, which is exactly the drift class the corpus exists to kill.

## The evidence (complete; nothing here is a judgment)
`runs/2026-09-18-tp-structure-hunt.md` (qa-70) + `runs/2026-09-17-tp-structure-shape-probe.md`
(qa-33, hunt tail stamped 2026-09-18): a TP workout `Structure` is **unreachable under our
current OAuth grant** on every route — range endpoint, by-id with the OWNING athlete's fresh
token, file export (`wod/file?format=json|mrc` → 401, a scope refusal: the same token 200'd on
`/v2/workouts` seconds earlier), `plan/{id}` → 405 to GET. Precise claim and no wider: NOT
"TP has no such API" — a file-export scope may be grantable (provider relations), and 405 is
wrong-method, not proven-absent.

**FS is untouched by this result.** Its structured detail arrives on a separate flagged fetch
(`json_fs_v1`, C5 on the corpus capture list — never yet seen). "Structure-parsed only" may
still have a live FS input even if TP never delivers one.

## The question
Given C1, what is Q-INT29's disposition for TrainingPeaks?

## Options
- **A (recommended): close for TP, pending FS evidence.** Record the provider fact in
  `training-peaks.md` ("structure unreachable under current OAuth grant, evidence
  2026-09-18"); zones stay NULL for TP by provider capability; `payload-usage-map.md` §7.3
  gains a scope note (TP: no input; FS: awaiting C5); Q-INT29's register row narrows to FS.
  The honest shape is "**no-op for TP, pending FS evidence**" — never the wider "Q-INT29 is
  a no-op". Trade-off: if TP later grants file-export scope, the row reopens — cheap, since
  the ruling text survives narrowed rather than deleted.
- **B: pursue TP file-export scope first, hold the disposition.** Keeps §7.3 fully alive at
  the cost of blocking a ratified-clause cleanup on an external party with unknown timeline.
- **C: leave the ruling as-is and wait for C2/C5.** Trade-off: the completeness meter and
  conformance surface would count a clause as covered that has never had an input — the
  drift this bundle exists to prevent.

Under **any** option: the fabricating default branches (`_classifyIntensity`'s ≤1.5⇒%FTP and
unknown-length⇒seconds, and the FS twin's same defaults) are wrong independently of the
disposition — they misread whatever they are fed. Their removal is app-side work that need
not wait on A-vs-B; only the *scope note* language does.

## What it gates (app-side)
- Removal of the fabricating fallback branches (cite this file + the two run files).
- `training-peaks.md` provider-fact fold; §7.3 scope note; Q-INT29 register-row narrowing.
- Nothing in the corpus ruling (Q-INT1/Q7/Q8) depends on this — separable decisions.

## Suggested spec home
`spec/integrations/training-peaks.md` (provider fact) + `payload-usage-map.md` §7.3 (scope
note) + `spec/integrations/OPEN-QUESTIONS.md` Q-INT29 row.

---

**Addendum (2026-09-18, later — before the desk renders this):** Xuan is creating a TP
premium trial account and re-running the probe against premium-built structured workouts
(same builder specimens, tier the only variable). That run can REFRAME this request before
it is ruled: if `Structure` (or planned IF/TSS) appears under a premium athlete's token,
the C1 result stops being a scope question and becomes a **tier** question — option A's
provider-fact wording would then be "basic-tier athletes: structure/planned-load not
delivered" rather than "unreachable under our OAuth grant", and the capture contract goes
premium-conditional instead of closed. The desk must carry that run's outcome (populated /
still-null / not-run) alongside this file; do not rule on the pre-trial evidence alone if
the run has happened.

**Outcome of the premium run (2026-09-18, later — `runs/2026-09-18-tp-premium-trial-probe.md`):**
the reframe did NOT materialize. The premium trial token got identical refusals
(`wod/file` 401, `plan/{id}` 405) and by-id `Structure` ABSENT on premium-built structured
workouts — the C1 result is **tier-independent** and option A's wording stands as written:
"unreachable under our OAuth grant". Planned IF/TSS, by contrast, DID populate under
premium — that feeds Q-INT26/DI-17, not this disposition.
