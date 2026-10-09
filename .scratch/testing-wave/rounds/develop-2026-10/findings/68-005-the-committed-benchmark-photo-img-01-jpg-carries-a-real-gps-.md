# 68-005 · The committed benchmark photo img-01.jpg carries a real GPS location in its EXIF; strip it before a wave uploads it again

- kind: idea
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: none (repo fixture benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg)
- decision: 

**Steps.**
1. Read the EXIF of benchmarks/ai-model-benchmark-2026-07/images/img-01.jpg with PIL before writing a test GPS tag for check 8.

**Expected.**
Fixture photos the waves upload carry no real location (runbook step 5, #112: nothing sent off the machine carries personal data).


**Actual.**
The committed file holds a full GPS IFD from an iPhone 14 Plus (a real latitude/longitude, altitude, speed and heading, dated 2025-07-19). This run overwrote it with a neutral point in the SCRATCH copy, so nothing real was uploaded. Since 68-004 shows the app uploads EXIF unchanged, any wave that uploads the fixture as-is sends that location to the meal-photos bucket. Idea: strip EXIF GPS from the benchmark images in the repo (or have the fixture step strip it), and add a line to the runbook.


**Evidence.**
- runs/68/notes.md: check 8 entry (coordinates not copied here on purpose).

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 75 (strip EXIF before the meal-photos upload; the benchmark fixture loses its GPS), fix wave 8 · Lee, 2026-10-09
