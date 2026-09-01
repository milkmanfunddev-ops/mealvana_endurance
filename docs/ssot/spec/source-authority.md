# SSOT — Source Authority & Precedence

**Status: REFERENCE (2026-08-03).** Governs every spec under `qa/spec/` — fueling, daily-macros,
recommendation. **When two sources disagree, this document decides which wins**, and every spec's
`targetBasis` / confidence tags inherit their meaning from the ranking here.

> This is the meta-SSOT. It does not set a single number. It sets the **rules by which numbers earn
> their authority**, so that "cited" means the same thing across the whole repo.

---

## 1 · Why this exists

Every spec in this repo tags each constant as either research-derived or a Mealvana design choice.
That discipline is only as good as the answer to *"whose research, and does it still hold?"* Sources
in sports nutrition are uneven: a textbook and a jointly-ratified position statement are not the
same kind of evidence, and treating them alike is how invented numbers acquire borrowed authority.
This file is the fixed reference that keeps the distinction honest.

**The core principle: authority is contextual, not a fixed leaderboard.** No single organization
wins every question. A source's weight depends on *what kind of document it is*, *whether the claim
sits inside that body's scope*, and *whether the edition is current*. The rules in §4 operationalize
that.

---

## 2 · Document taxonomy — the first thing to classify

Before ranking *who* said something, classify *what kind of statement* it is. This ordering holds
before any organization is even named.

| Type | What it is | Weight | In this repo |
|---|---|---|---|
| **Position stand / statement** | An organization's official, *graded*, peer-reviewed, ratified stance; periodically reaffirmed or retired | **Highest** | Thomas 2016; NATA 2017; Sawka 2007 (superseded) |
| **Consensus statement** | An expert panel convened (often by the IOC) to agree a position | High, but represents the panel, not a standing institution | IOC statements (not currently cited) |
| **Primary research** | A single peer-reviewed study reporting original data | Authoritative *for its measured quantity*, weak for general prescription | Mudie 2014 (`K`); Nose 1988; Shirreffs 1996 |
| **Review / textbook** | A secondary source summarizing primary studies | **Mechanism only** — never sets a standard | Jeukendrup & Gleeson 2019 |

**The load-bearing consequence:** a textbook that disagrees with a position stand on a *number*
loses. A textbook that *explains why* a number is what it is (mechanism) is invaluable and
uncontested. We used J&G for gastric-emptying physiology, the osmolality argument, and the
sodium-retention pathway — never to override a position statement's figure.

---

## 3 · The bodies

| Body | What it is | Grades its claims? | Most authoritative for |
|---|---|---|---|
| **ACSM** — American College of Sports Medicine (1954) | Major sports-medicine college: physicians, physiologists | Yes | Exercise physiology, hydration, thermoregulation |
| **AND** — Academy of Nutrition and Dietetics (the former **ADA**, renamed 2012) | Largest US body of registered dietitians | Yes — Evidence Analysis Library | Clinical & dietary nutrition |
| **DC** — Dietitians of Canada | Canadian counterpart to AND | Yes | Same, Canadian scope |
| **NATA** — National Athletic Trainers' Association | The athletic-trainer profession (sideline care) | Yes — SORT (A/B/C) | Field hydration, acute fluid replacement |
| **ISSN** — International Society of Sports Nutrition | Specialist sports-nutrition society; prolific position stands | Yes — evidence categories | Nutrient timing, supplements, granular/current topics |
| **IOC** — International Olympic Committee | Convenes elite-sport *consensus* statements | Consensus, not graded | Elite/Olympic athletes, supplements, RED-S |

**Note on naming:** the sports-*nutrition* society is **ISSN**, not "ISSM." There is an
international sports-*medicine* federation (FIMS), but it does not feature in the nutrition
literature and is not cited in this repo.

---

## 4 · The precedence rules (load-bearing — this is what a spec author applies)

Six rules, derived and stress-tested across the pre-workout work. Apply them **in order**.

**R1 · Classify the document type first (§2).** A graded position stand outranks a consensus panel,
which outranks primary research used as general prescription, which outranks a textbook. Settle
this before comparing organizations.

**R2 · A jointly-ratified stand outranks a single-society stand.** Breadth of independent
ratification is the strongest signal short of a government guideline. **Thomas 2016** — jointly
ratified by ACSM, AND *and* DC — is the top authority in this repo for general-athlete fuelling and
hydration, and is the document the others cite rather than contradict.

**R3 · Scope gates authority.** A body's stand is authoritative *only for claims inside its remit*.
NATA is sharpest on field/acute fluid questions (hence `R_CEILING` from NATA 2017); the IOC's remit
is the elite athlete, not the recreational user this product serves. A stand outside its scope does
not outrank one inside its scope.

**R4 · Currency gates authority — but only for the claim the successor actually covers.** A newer
edition supersedes an older one *on the points it addresses*. Where the successor is **silent** on a
case the predecessor covered, the predecessor still governs — this is not the same as citing a
superseded *number* against a successor that gives a different one. *(This is why ACSM 2007 lost to
Thomas 2016 on the base fluid dose, yet ACSM 2007 still **won** on the dark-urine correction, which
Thomas dropped without replacing.)*

**R5 · Assess the chapter, not the book.** A source's authority is not uniform across itself. Weight
the specific passage by its own citations and recency, not the volume's reputation. *(J&G ch. 9's
median citation year is 1992 and it never cites Thomas 2016; ch. 5 is current. A figure carrying no
citation at the point of use — e.g. J&G p. 131's emptying percentages, p. 247's ADA/DC dose — is
treated as uncited regardless of the book's standing.)*

**R6 · Agreement between a source and its own ancestor is not corroboration.** Two documents in the
same lineage restating a figure count as **one** source, not two. *(The rebound-hypoglycaemia
conclusion appears in five places all authored or co-authored by Jeukendrup; a J&G figure citing an
earlier Jeukendrup paper is family, not confirmation. Independent corroboration must come from a
separate lineage.)*

---

## 5 · Evidence-grading systems (so a tag's meaning is unambiguous)

When a spec cites a graded recommendation, the grade *is* part of the claim. Reference:

| System | Used by | Scale | Example in this repo |
|---|---|---|---|
| **SORT** (Strength of Recommendation Taxonomy) | NATA | A (consistent, quality evidence) · B (limited/inconsistent) · C (consensus/usual practice) | NATA 2017 Rec 18 = **SOR: B** — mechanism affirmed, individualization urged, no number |
| **Evidence Analysis Library grades** | AND / ACSM joint | I–V quality, Grade I–IV / Strong–Weak | Thomas 2016's recommendations carry these |
| **ISSN evidence categories** | ISSN | A/B/C by study design | Kerksick 2017's summary points |

A **Grade B / SOR: B** claim is a real recommendation *and* an admission the evidence is limited —
carry both. Never quote the recommendation and drop the grade.

---

## 6 · Standing rulings from this repo (worked precedent)

How §4 has actually been applied, so future authors extend the pattern rather than relitigate it:

| Question | Ruling | Rule |
|---|---|---|
| Base pre-exercise fluid dose | **Thomas 2016** (5–10 ml/kg), not ACSM 2007 (5–7) | R2, R4 |
| Dark-urine correction (+3–5 ml/kg at ~2 h) | **ACSM 2007** — Thomas is silent, predecessor still in scope | R4 |
| Pre-exercise carbohydrate (1–4 g/kg, 1–4 h) | **Thomas 2016 Table 2** (origin Burke 2011), **not** Kerksick 2017 | R2, R6 |
| Tolerated gastric volume (`R_CEILING` = 400 ml) | **NATA 2017** — sharpest on field fluid tolerance | R3 |
| Gastric-emptying coefficient (`K` = 3.2 h⁻¹) | **Mudie 2014** (primary, states the coefficient) over Grimm/Bertoli | R1 |
| Gastric-emptying *mechanism* (exponential, volume-dependent) | **J&G 2019** — textbook, mechanism only | §2 |
| ADA/DC "500 ml at t−15" | **Not used** — uncited in J&G, wrong section, no ref-list entry | R5 |
| Rebound hypoglycaemia as a dosing constraint | **Not used** — single lineage, conclusion is "no performance effect" | R6 |
| Per-macro food-composition % thresholds | **Mealvana design choice** — corpus is qualitative; only Tougas meal + 8% drink rule are cited | R1, §2 |

---

## 7 · Currency register

Position stands age. Track the ones the repo depends on, and re-verify rather than assume.

| Source | Status (as of 2026-08-03) | Known staleness | Recheck |
|---|---|---|---|
| **Thomas / Erdman / Burke 2016** (ACSM/AND/DC) | **Current** — no newer joint statement found on search | Describes glycerol as WADA-prohibited; **glycerol delisted 2018** | Annually — a replacement supersedes the fluid band, window, carb box and the gate rationale in one move |
| **NATA 2017** (McDermott et al.) | Current | — | Annually |
| **Sawka 2007** (ACSM fluid stand) | **Superseded** for the base dose by Thomas 2016 | Retained only for the dark-urine branch (R4) | — |
| **ISSN / Kerksick 2017** | Current within ISSN's remit | Not used for the pre-exercise carb dose (R2, R6) | On ISSN reissue |

**The single highest-leverage maintenance task in the repo:** confirm annually whether a joint
ACSM/AND/DC statement newer than 2016 exists. Because so much rests on Thomas 2016 (fluid band,
fluid window, carbohydrate box, gate rationale), one replacement cascades through every fueling
spec. This is `pre-workout.notes.md` §5.9, elevated here to a scheduled check.

---

## 8 · The rule, in one sentence

**A jointly-ratified, formally-graded position statement outranks a single-society stand, which
outranks a consensus panel outside its remit, which outranks primary research used as prescription,
which outranks a textbook — but only for a claim inside that body's scope, and only in its current
edition; and two documents in one lineage count as one source.**

Everything in §4 unpacks that sentence. When in doubt, return to it.

---

## Literature (the primary records behind the rankings)

- **Thomas DT, Erdman KA, Burke LM.** *ACSM Joint Position Statement. Nutrition and Athletic
  Performance.* Med Sci Sports Exerc. 2016;48(3):543–568. PMID 26891166. Co-published J Acad Nutr
  Diet 2016;116(3):501–528 (PMID 26920240).
- **McDermott BP, et al.** *NATA Position Statement: Fluid Replacement for the Physically Active.*
  J Athl Train. 2017;52(9):877–895.
- **Sawka MN, et al.** *ACSM Position Stand: Exercise and Fluid Replacement.* Med Sci Sports Exerc.
  2007;39(2):377–390. **Superseded.**
- **Kerksick CM, et al.** *ISSN Position Stand: Nutrient Timing.* J Int Soc Sports Nutr. 2017;14:33.
- **IOC Consensus Statement: Dietary Supplements and the High-Performance Athlete.** Int J Sport
  Nutr Exerc Metab. 2018;28(2):104–125.
- **Jeukendrup A, Gleeson M.** *Sport Nutrition.* 3rd ed. Human Kinetics; 2019. **Secondary source —
  mechanism only.**
