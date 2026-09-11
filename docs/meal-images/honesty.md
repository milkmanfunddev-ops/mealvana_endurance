# How honest the meal library's pictures are

The number that matters is not how many meals have a picture. It is how many
show a picture that is a picture *of that meal*.

Those are different numbers, and the difference is the whole problem. The old
headline — 94.5% coverage — counted fifteen meals represented by a photograph of
water running over pebbles as fifteen covered meals. Nothing had ever asked the
question a person asks in half a second when they look at the list.

**Honesty** = meals showing an image a judge rated `ok`, plus meals honestly
showing nothing (blocked, with a reason), over every active meal. A `weak`
picture is not misleading but is not honest either; a `wrong` one is the work
queue. A meal with no verdict is unmeasured and counts as neither.

Regenerated from the database — nothing here is estimated:

```bash
node scripts/meal-images/09-image-report.mjs --write   # the measure
node scripts/meal-images/09-image-report.mjs --wrong    # the whole work queue
```

The verdicts these figures count are statements about the picture the
compositor drew, which is pinned to the picture the athlete sees. Changing the
grid invalidates all of them — the protocol is in
[README.md](README.md#compositor-parity--read-before-touching-the-grid).

## What the first measurement found (2026-09-10)

**Dish photos are the worst rung, not the safe one.** The whole strategy assumed
the 708 meals carrying a real photograph were fine and that the work was in the
mosaics; they had never been judged. They are **76% wrong** — worse than the
mosaics at 46%, and they are wrong in a way no ingredient sourcing can fix,
because the photograph is already there and is of something else. "Eggs & turkey
bacon on toast" is a carton of raw eggs. "Congee with pickled vegetables" is a
food-court interior.

That reorders the remaining work: the largest honest-picture deficit is not the
170 transformed meals ticket 04 was scoped around, it is the 539 meals already
wearing a photograph of the wrong food.

**Only 9.7% of judged pictures were rated `ok`.** A third were `weak` — not
misleading, but saying almost nothing. The library is further from honest than
the 47.5%-of-mosaics sample suggested, and the sample was not pessimistic
enough.

## What sourcing dish photographs changed (2026-09-10)

Pass 10 worked the 211 Transformed meals — the ones a Mosaic can never serve —
searching licensed stock by dish name and showing every candidate to the judge
**before** storing it. It served **53** across three runs, refused 301
candidates, and cost $1.32.

A 23% hit rate is the honest ceiling of this approach, not a disappointment.
"Marathon-training smoothie (No Meat Athlete)" and "Low-FODMAP chocolate chia
pudding" are not photographs anyone has taken; the stock libraries are the
constraint, exactly as the retry rounds on the ingredient bank suggested.

The judge refusing 85% of what the ranking offered is the point of the change.
Every one of those 279 would have been accepted by a text score, and the 539
wrong dish photos in the measurement below are what that produces.

**Every Transformed meal now shows either an `ok` photograph or its icon.** 61
carry one, 159 are flagged blocked with a reason, and 28 that were wearing a
photograph of the wrong food had it retired — no Transformed meal wears a Mosaic,
and none shows a picture rated `wrong`. Nine still show a `weak` photograph:
thin rather than misleading, and trading those for an icon would be a loss.

**Sourcing had to learn not to repeat itself.** Stock search is narrow: ask four
green-smoothie meals for a green smoothie and all four are offered the same
top-ranked picture, and the first run gave four meals one photograph of a
blueberry shake. Pass 10 now reads every photograph the library is already
showing and skips it — one query and a set test, far cheaper than a rail
reasoning about what its neighbours display. The four were handed back and
re-sourced; the honesty figure did not move, because a meal that trades a
repeated picture for its icon is honest either way.

The library still holds **128 photographs shown by more than one meal** from
earlier passes. That is ticket 07's population, and this pass no longer adds
to it.

## What repairing the wrong pictures changed (2026-09-10)

Ticket 05 took every meal showing a picture rated `wrong` — 503 photographs,
367 grids, 4 single tiles — and every recipe still wearing tiles whatever its
verdict (58 more), and asked pass 10 for a photograph of the dish. **Honesty
went from 29.4% to 75.3%, and nothing in the library is rated `wrong` any
more.**

It got there mostly by taking pictures away, not by finding them. **77 meals
found an `ok` photograph**, 8% of the 932: the stock libraries hold "Pasta,
grilled chicken & steamed broccoli" no better than they held "Low-FODMAP
chocolate chia pudding". The rest had their wrong picture retired. A meal
whose photograph was of the wrong food drops to the grid it is entitled to,
and the judge looks at that grid before the meal is left — **55 were rated
`ok` and kept**. A `weak` grid is refused like a wrong one (Lee, 2026-09-10):
a meal that was showing the wrong food does not get to keep a thin picture in
its place. Everything else shows its icon.

So **coverage fell from 80.9% to 41.8%**, and 1,118 meals now show an icon.
That is the spec's trade — fewer pictures, each one believable — and it is the
largest visible change this work has made to the Meals tab.

The new reason, `grid_refused` (689), is the population a better picture
would help most. Each of those meals once showed something the judge refused,
and the ladder remembers the refused grid (`image_rejected_mosaics`) so pass 3
cannot hand it back. A grid whose tile photograph is later replaced is a
different picture, and the ladder offers it again.

Recipes wearing tiles went from 127 to 50 — 42 `weak`, 8 `ok`. A recipe whose
grid was not wrong keeps it when no photograph turns up.

**The contact sheet found what the row counts could not, again.** Four meals
had been given a photograph another meal was already showing. Pass 10's
"already in use" set was built from stored addresses, and a mirrored archive
photograph's stored address is ours, so a restarted run forgot it — and this
run was restarted twice (once to take the `weak` rule, once after the machine
ran short of memory). The set now keys on the photograph's source page as well.
Two of the four found another photograph; an açaí bowl and "White bread with
jam" still share theirs, and two chicken tikka masala meals wear different
files of what looks like the same picture. Those are ticket 07's.

**What it cost.** About $8, estimated at list price. The ledger below records
$0.57 of it: the first two runs were stopped before they could append a row —
one deliberately at meal 82, to adopt the `weak` rule, and one by the system
at meal 780 of 850. From their logs they judged about 1,780 candidates and
roughly 175 fallback grids, which at the $0.004 a call measured on the third
run is about $7.50.

<!-- honesty:begin -->
_Measured 2026-09-11, against mosaic geometry v1. Regenerated by
`node scripts/meal-images/09-image-report.mjs --write`; do not edit by hand._

## Honesty: 75.3%

**1447 of 1922 active meals** either show a picture a judge rated `ok`, or
honestly show nothing. 804 of them (41.8%) have *a* picture —
that is coverage, and the gap between the two numbers is the work.

| mode | meals | ok | weak | wrong | unjudged |
|---|---:|---:|---:|---:|---:|
| `dish` | 292 | 170 | 122 | 0 | 0 |
| `mosaic` | 482 | 148 | 334 | 0 | 0 |
| `tile` | 30 | 11 | 19 | 0 | 0 |
| `none` | 1118 | — | — | — | — |

### Showing nothing — 1118 meals

| reason | meals |
|---|---:|
| `grid_refused` | 689 |
| `multi_part_single_tile` | 198 |
| `transformed` | 160 |
| `no_bank_tile` | 71 |

### Showing something wrong — 0 meals

Most-surfaced first: frequency, then how many rails the meal is eligible for, then how
few athletes an allergen hides it from. This is the work queue for tickets 04 and 05.

_None._
<!-- honesty:end -->

## What the measuring cost

A frontier model, because the judgement is subtle — the cheap model's blind
spot is exactly this class of error. Estimated at list price, so the gateway's
invoice is the authority. A run that is killed keeps every verdict it had
reached but appends no row, so the ledger under-reports what was spent by
whatever an abandoned run cost.

Pass 8 buys one call per meal already showing a picture. Pass 10 buys calls on
candidates it mostly refuses, so its `judged` counts candidates rather than
meals — and every refusal is remembered, so no later run pays for it twice.

| finished | pass | model | geometry | judged | skipped | tokens in | tokens out | ≈ USD |
|---|---:|---|---|---:|---:|---:|---:|---:|
<!-- runs:begin -->
| 2026-09-10 18:33 | 8 | `anthropic/claude-sonnet-5` | v1 | 6 | 0 | 8,758 | 567 | $0.02 |
| 2026-09-10 18:36 | 8 | `anthropic/claude-sonnet-5` | v1 | 8 | 0 | 11,599 | 531 | $0.03 |
| 2026-09-10 19:03 | 8 | `anthropic/claude-sonnet-5` | v1 | 1494 | 0 | 2,199,214 | 226,521 | $6.66 |
| 2026-09-10 20:50 | 10 | `anthropic/claude-sonnet-5` | — | 327 | 0 | 479,341 | 25,885 | $1.22 |
| 2026-09-10 21:05 | 10 | `anthropic/claude-sonnet-5` | — | 12 | 0 | 17,595 | 822 | $0.04 |
| 2026-09-10 21:26 | 10 | `anthropic/claude-sonnet-5` | — | 15 | 0 | 22,147 | 1,886 | $0.06 |
| 2026-09-11 01:41 | 10 | `anthropic/claude-sonnet-5` | — | 142 | 0 | 208,370 | 13,104 | $0.55 |
| 2026-09-11 01:43 | 10 | `anthropic/claude-sonnet-5` | — | 5 | 0 | 7,228 | 311 | $0.02 |
<!-- runs:end -->
