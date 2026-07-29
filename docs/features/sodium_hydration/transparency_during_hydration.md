# During-Workout Hydration — Transparency Copy V1

> **Status:** Design updated — reflects Algorithm v2.1 (April 8, 2026) with latest spec changes: gate now produces 30% conservative target + ceiling (not zero); T1/T2 transition hydration (300 ml each) added to multi-segment calculation; duration table now explicitly includes <60 min · 30% tier; redistribution example updated to use heavy sweater scenario where transitions + redistribution both apply.

## Live Interactive Prototype

Hosted at claude.site (see Notion for live embed).

---

## Overview

This page documents the copy, structure, and interaction design for the **during-workout hydration section** of the Nutrition Transparency info drawer. Updated to reflect Algorithm v2.1 — the calculation chain is now 5 steps (up from 3) and replacement percentage scales with workout duration rather than using a flat 80%.

---

## Calculation Chain (5 Steps + Safety Check)

| Step | What it does | Confidence |
|------|-------------|------------|
| 1. Base sweat rate | Sets base from sweater type (percentile-mapped) or known test value | High |
| 2. Temp adjustment | +0.04 L/hr per °C above 22°C baseline, clamped 0.50–1.80× | Medium |
| 3. Humidity adjustment | Small multiplier above 50% RH, max 1.10× | Medium |
| 4. Indoor adjustment | 1.30× if no convective cooling | Low — estimate |
| 5. Duration-scaled replacement | 30% soft target at <60 min; 50% at 60–90 min → 80% at 240+ min. Gate fires but still calculates conservative target + ceiling | Medium–High (<60 min: Low) |
| T1/T2 transition hydration | 300 ml fixed at each transition; subtracted from bike + run requirement before distributing rate across drinkable segments | Low — practitioner consensus |
| Safety check | Flags if deficit > 2% body weight even at recommended intake | High |

---

## Key Changes from Previous Version

- **Sweat rate tiers updated:** Light=0.90, Medium=1.28, Heavy=1.66 L/hr (was 0.75/1.25/2.0) — now based on Barnes & Baker 2019, n=1,303, mapped to 25th/50th/75th percentiles
- **Temperature baseline:** 22°C neutral (was 20°C) — Jenkins 2023 is the source
- **Humidity step added:** Small multiplier (max 1.10×), Low–Medium confidence
- **Indoor adjustment added:** 1.30× — Low confidence, needs validation
- **Replacement % is now duration-scaled** (was flat 80%): <60 min → 30% soft target (drink to thirst, with guardrail); 60–90 min → 50%; 90–150 min → 60%; 150–240 min → 70%; 240+ min → 80%
- **Gate behavior changed:** <60 min gate no longer exits with zero. Now calculates 30% conservative target + floor + ceiling and presents: "If you do drink, aim for ~X ml/hr. Don't exceed Y ml/hr."
- **T1/T2 transition hydration added (multi-segment):** 300 ml fixed at each transition. Required intake is calculated race-wide, transitions subtracted first, remainder distributed across bike + run. Floor also reduced by transition intake. This drops Olympic tri rates from ~943 → 679 ml/hr in the standard example.
- **Safety check added:** Flags expected dehydration >2% and >3% body weight

---

## Formula Display

**Single sport (90-min run, 65 kg, medium sweater, 22°C):**

```
① medium sweater       → 1.28 L/hr  (50th pct)
② 22°C                 × 1.0  = 1.28 L/hr
③ 55% humidity         × 1.01 = 1.29 L/hr
④ outdoor              × 1.0  = 1.29 L/hr  effective
⑤ 90 min → 50% → 1.29 × 1000 × 0.50 = 645 ml/hr
────────────────────────────────────────────
   645 ml/hr × 1.5 hr = 968 ml (33 oz)
↓ floor   = (1,935 − 1,300) ÷ 1.5 = 423 ml/hr  (21 oz total)
↑ ceiling = min(800, 1,290) = 800 ml/hr (41 oz total)
   range → 21–41 oz
✓ deficit = 1,935 − 968 = 967 ml → 1.5% BW  (< 2% ✓)
```

**Short workout gate (45-min run, 70 kg, medium sweater, 22°C):**

```
① medium sweater → 1.28 L/hr
②–④ no adjustments at 22°C outdoor → 1.28 L/hr effective
⑤ 45 min < 60 AND 22°C < 30 → gate fires
   30% conservative → 1,280 × 0.30 = 384 ml/hr
↓ floor   = 0 ml/hr  (loss < 2% BW naturally)
↑ ceiling = min(800, 1,280) = 800 ml/hr
   → "Drink to thirst. If you drink: aim ~384 ml/hr (10 oz). Max 800 ml/hr (20 oz)."
```

**Multi-segment (Olympic tri, 68 kg, known rate 1,300 ml/hr, 26°C):**

```
① known rate 1.30 L/hr
② 26°C × 1.16 = 1.51; ③ 55% humid × 1.01 = 1.52 L/hr effective
⑤ 140 min total → 60%
   total loss = 3,171 ml  |  required = 3,171 × 0.60 = 1,903 ml
   T1 + T2 = 600 ml  |  remaining = 1,903 − 600 = 1,303 ml
   rate = 1,303 ÷ 1.92 hr = 679 ml/hr
↓ floor = (3,171 − 1,360 − 600) ÷ 1.92 = 631 ml/hr
↑ ceiling = min(1,200, 1,520) = 1,200 ml/hr (cycling)
   679 > 631 → no floor override  |  679 < 1,200 → no ceiling cap
   bike: 679 × 1.08 = 733 ml (25 oz)  |  no redistribution needed
✓ race deficit = 1,270 ml → 1.9% BW  (< 2% ✓)
```

---

## Range Derivation — Active Override Logic

The floor and ceiling are not just display ranges — they actively override the percentage-based recommendation:

```
final = percentage-based recommendation
final = max(final, floor)    ← floor can raise the recommendation
final = min(final, ceiling)  ← ceiling hard-caps it
```

If ceiling < floor (athlete cannot stay within 2% BW loss), the ceiling wins. GI safety and hyponatremia prevention take priority. The algorithm flags aggressive pre-hydration.

**Floor** = `(total_loss − 2% × BW) ÷ duration_hr` — can be 0 if deficit naturally stays within 2%

**Ceiling** = `min(GI_limit, sweat_rate_ml_hr)` — dual constraint:
- GI limit: 800 ml/hr (running), 1,200 ml/hr (cycling)
- 100% sweat rate cap: never drink more than you lose (hyponatremia guard)

*Floor: Sawka et al. (2007) ACSM — 2% BW threshold · GI ceiling (running): Peters (1999), Pfeiffer (2012) — medium confidence · GI ceiling (cycling): Coyle (1992), Lambert (1997) — high confidence · Hyponatremia ceiling: Hew-Butler et al. (2015), Mosler et al. (2020) — high confidence*

---

## Always-Visible Copy

Your fluid target starts with a duration-based replacement strategy, then two overrides are applied: a **floor** that raises the target if needed to keep you within 2% body weight loss, and a **ceiling** that caps it at what your gut can absorb and what's safe for blood sodium. The final recommendation is always between those two bounds.

---

## Safety Flag Copy

> ⚠️ Even at this intake you may lose ~1.2% body weight. Pre-hydrate before this workout and rehydrate immediately after.

(Shown when deficit > 2% BW. More urgent version at >3%.)

---

## The Full Story Copy

### Why does sweat rate drive the target?

Every athlete loses fluid at a different rate — genetics, fitness, and heat acclimatization all play a role. A dataset of 1,303 athletes gives us reliable population benchmarks mapped to percentile tiers.

**Sweat rate tiers:** Light · 0.90 L/hr · 25th pct | Medium · 1.28 L/hr · 50th pct | Heavy · 1.66 L/hr · 75th pct

*Barnes & Baker et al. (2019) — Journal of Sports Sciences, n=1,303* · **High confidence**

---

### Why does temperature change the target?

Your body sweats more in heat to maintain core temperature. Research directly measured a sweat rate increase of **0.04 L/hr per °C** above the neutral baseline of 22°C. Below 22°C the multiplier drops toward a minimum floor of 0.50×.

*Jenkins et al. (2023) — Experimental Physiology* · **Medium confidence**

---

### Does humidity matter?

High humidity slows sweat evaporation, meaning your body sweats slightly more to achieve the same cooling effect. The effect is small — at most 10% above 50% relative humidity.

> ⚠️ **Transparency note:** Jenkins et al. (2023) found humidity did **not significantly increase sweat rate** on its own. The small multiplier (max 1.10×) is Mealvana's conservative practical estimate — not directly validated by the research.

**Medium confidence**

---

### Why do you sweat more indoors?

Moving air outdoors carries heat away through convection, reducing how hard your sweat system has to work. On an indoor trainer without a fan, that cooling is gone. We apply a **1.30× multiplier** for indoor sessions.

> ⚠️ **Transparency note:** The 1.30× indoor multiplier is conceptually well-supported but **not directly quantified in published research**. This is our lowest-confidence adjustment — we plan to refine it with user data over time.

**Low confidence — estimate**

---

### Why is drinking too much water also dangerous?

Overhydration — specifically exercise-associated hyponatremia (EAH) — occurs when blood sodium drops too low because excess fluid dilutes it. Sodium is critical for nerve and muscle function, and when plasma sodium falls below about 130 mmol/L, symptoms range from nausea and confusion to, in severe cases, seizure and death. EAH has been documented in marathon runners, triathletes, and cyclists who drank far beyond their sweat losses, often following the old advice to "drink as much as possible."

This is why the algorithm's ceiling is **100% of your sweat rate** — never more than you lose. Even if your gut could absorb more, drinking beyond your losses actively dilutes blood sodium. If your sweat rate is lower than the GI limits (800 ml/hr running, 1,200 ml/hr cycling), your sweat rate becomes the true ceiling. Plain water carries the highest EAH risk because it adds volume with no sodium.

*Hew-Butler et al. (2015) — Third International EAH Consensus · Mosler et al. (2020) DGE · Sawka et al. (2007) ACSM*

### Why does the replacement % change with duration?

Short workouts don't need structured hydration — the deficit stays small. For workouts under 60 minutes in mild conditions, drinking to thirst is sufficient. As effort lengthens, cumulative losses grow and their impact on performance increases.

**Duration tiers:**
- <60 min · 30% soft target (drink to thirst — 30% is a conservative guardrail, not a structured recommendation)
- 60–90 min · 50%
- 90–150 min · 60%
- 150–240 min · 70%
- 240+ min · 80%

For workouts under 60 minutes in mild conditions, structured hydration adds no measurable benefit — multiple studies show no performance gain from fluid replacement at this duration. The 30% figure is not from a specific study; it provides an upper-bound guardrail for athletes who want a number. Drinking to thirst is the primary recommendation. The 80% ceiling is the upper practical limit — replacing more risks overhydration (hyponatremia) if sodium intake is insufficient.

*Sawka et al. (2007) ACSM; Coyle (1992); Mosler et al. (2020) DGE; Tiller et al. (2019) ISSN; Robinson et al. (2003); McConell et al. (1999) — <60 min gate* · **Medium confidence (60–240 min) / High confidence (240+ min) / Low confidence (30% soft target)**

---

### What does the warning flag mean?

Even at the recommended intake, heavy sweaters in hot conditions may lose more than 2% of body weight — the threshold where performance begins to decline. When this happens we flag it so you can **pre-hydrate before and rehydrate more aggressively after.** The recommendation itself is still correct.

*ACSM Position Stand (Sawka 2007); Cheuvront & Kenefick (2014) — Comprehensive Physiology* · **High confidence**

---

## Evidence Strength Summary

| Component | Confidence | Source |
|-----------|------------|--------|
| Base sweat rate tiers | High | Barnes/Baker 2019, n=1,303 |
| Temperature coefficient | Medium | Jenkins 2023 |
| Humidity multiplier | Medium | Jenkins 2023, Che Muhamed 2016 |
| Indoor multiplier | Low | Conceptual — no direct quantification |
| <60 min gate (no structured plan) | High | Multiple studies — Robinson 2003, McConell 1999, Backx 2003 |
| 30% soft target (<60 min) | Low | Not from a specific study — conservative guardrail only |
| T1/T2 transition hydration (300 ml) | Low | Practitioner consensus, not peer-reviewed |
| 50% at 60–90 min | Medium | Noakes ad libitum data |
| 60% at 90–150 min | Medium | ACSM 0.4–0.8 L/hr guideline |
| 70% at 150–240 min | Medium | Coyle 1992 |
| 80% at 240+ min | High | DGE position stand; ISSN ultra guidelines |
| 2% BW safety threshold | High | ACSM 2007, Cheuvront 2014 |

---

## Design Decisions

### Confidence badges in the Full Story

Each section now shows a colored confidence badge (High / Medium / Low) that directly reflects the evidence table. This is unique to the hydration section because the algorithm explicitly grades its own evidence — surfacing that honestly builds trust with coaches.

### Sweat test note

A "Learn how →" link inside the sweat rate editor prompts athletes with weighed test data to use their known rate. This eliminates the single largest source of estimation error in the model.

### Safety flag

The orange flag below the formula appears conditionally — only when deficit > 2% BW. It's not a warning that the recommendation is wrong; it's a prompt to pre- and post-hydrate. The copy makes this distinction explicit.

---

## References

1. Barnes & Baker et al. (2019) — [PubMed 31230518](https://pubmed.ncbi.nlm.nih.gov/31230518/)
2. Baker LB. (2017) — [PubMed 28332116](https://pubmed.ncbi.nlm.nih.gov/28332116/)
3. Jenkins DJ et al. (2023) — [PubMed 36537856](https://pubmed.ncbi.nlm.nih.gov/36537856/)
4. Sawka et al. (2007) ACSM — [PubMed 17277604](https://pubmed.ncbi.nlm.nih.gov/17277604/)
5. Mosler S et al. (2020) DGE — [Link](https://www.germanjournalsportsmedicine.com/archive/archive-2020/issue-7-8-9/fluid-replacement-in-sports/)
6. Coyle EF (1992) — [PubMed 1406205](https://pubmed.ncbi.nlm.nih.gov/1406205/)
7. Tiller NB et al. (2019) ISSN — [PubMed 31687085](https://pubmed.ncbi.nlm.nih.gov/31687085/)
8. Cheuvront & Kenefick (2014) — [PubMed 24382024](https://pubmed.ncbi.nlm.nih.gov/24382024/)
