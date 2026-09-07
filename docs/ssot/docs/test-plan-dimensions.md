# Test-plan dimension analysis — the mandatory sweep

**Why this exists (2026-08-18, the mark-done teleport).** The macro-dashboard plan enumerated
every chain and invariant, every manifest row had a test — and the worst bug of the bundle
(mark-done on a non-current day relocating the workout onto today) sailed through, because every
G1 pin was written on the *current* day. The contract, the vectors, the widget tests and the
Patrol flow all agreed with each other and were all blind in the same direction. A test plan
that lists *contracts* but not *input dimensions* inherits the spec author's frame, including
its blind spots.

**The rule:** every feature test plan gets a `## Dimensions` section, written BEFORE the
chains/invariants are pinned. For each user-facing contract (gesture, write, surface state),
list the axes along which its inputs genuinely vary, and mark each cell: pinned (by which
test), deliberately excluded (why), or **open**. An axis with no marked cells is the finding.

Standard axes — start here, prune what truly doesn't apply, add domain-specific ones:

| Axis | Cells | Classic failure it catches |
|---|---|---|
| **Time relativity** | past day / current day / future day; before vs after the item's own time | the mark-done teleport; passive-SKIPPED derivation |
| Repetition / inverse | do it twice; do → undo → redo; interleave with its inverse | stuck state, non-idempotent writes |
| Concurrency with recomputes | act during an in-flight recompute / upload drain | the post-unskip reveal race; energy-card blink |
| Connectivity | online / offline / server rejects the write | offline-first rollback paths, dirty-row behaviour |
| Auth & identity | signed-in owner / another account / anonymous | RLS visibility (the probe-account self-skip) |
| Data provenance | user-created / platform-imported / synced-verified | TP-'skipped' semantics; G3 suppression scope |
| Wire round-trip | value survives upload → server → download byte-identically | the timestamptz shift (only a LIVE cell can pin this — mark it for probe-live/T15, never claim it from an in-process test) |
| Volume / emptiness | zero items / one / many / duplicates | tuck ordering, empty-state rendering |

Conventions:
- The section is a table per contract or one matrix for the surface — whichever stays readable.
- "Deliberately excluded" requires a reason a reviewer can reject; "obviously fine" is not one.
- The gap pass (stage 6) treats an open cell exactly like an owned-by-NONE link: surface it,
  get it pinned or ruled out, never leave it silent.
- Retrofit note: `docs/feature-test-plans/macro-dashboard.md` carries the first worked example.
