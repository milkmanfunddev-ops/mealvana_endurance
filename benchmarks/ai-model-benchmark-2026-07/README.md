# AI model-quality benchmark — 2026-07

Asset set for the **2×2 model-quality benchmark** agreed in the 2026-07-24 Xuan+Lee meeting:
**{Haiku, Sonnet} × {compressed image, uncompressed image}**, over a fixed set of food
images + text descriptions. Goal: decide whether to move any AI calls off Sonnet onto Haiku,
and whether the ~1000px image-compression lever hurts accuracy — quality is the deciding
factor, cost is affordable either way.

Related tracking:
- Sprint Task (assets, Xuan): *Collect & send Lee the model-benchmark asset set* — https://app.notion.com/p/Collect-send-Lee-the-model-benchmark-asset-set-10-food-images-10-long-10-short-descriptions--3a7e3fdb754c81f4a21de1b905f8f2f8
- Sprint Task (run it, Lee): *Run the 2×2 model-quality benchmark → Notion report* — https://app.notion.com/p/Run-the-2x2-model-quality-benchmark-Haiku-Sonnet-x-compressed-uncompressed-image-over-the-fixe-3a7e3fdb754c81b0ae52dd88980d49ac
- Engineering decision: *LLM/AI token-cost control* — https://app.notion.com/p/LLM-AI-token-cost-control-cost-reduction-levers-release-gating-monetization-plan-382e3fdb754c81509b43e894314e6ebc

Consumers under test: `supabase/functions/analyze-meal-photo` (image path) and
`supabase/functions/describe-meal` (text path).

## Layout

- `originals/` — the images exactly as Xuan supplied them (10 iPhone HEIC camera photos +
  1 PNG). Provenance; do not edit.
- `images/` — model-ready copies. HEICs converted to JPEG (quality 80, **full resolution,
  no resize** — the Anthropic vision API rejects HEIC). These are the **source** for both
  image arms; the harness produces the compressed (~1000px) and uncompressed variants from
  them per the benchmark's compression factor.
- `descriptions/descriptions.json` — the 10 long + 10 short text descriptions for the
  `describe-meal` path (draft, ready to edit).

## Image manifest

| Benchmark id | Original | Format | Dimensions | Note |
|---|---|---|---|---|
| img-01 | IMG_4914.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-02 | IMG_5343.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-03 | IMG_5587.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-04 | IMG_6329.heic | HEIC→JPEG | 4032×3024 | camera photo |
| img-05 | IMG_6525.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-06 | IMG_6620.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-07 | IMG_7238.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-08 | IMG_7600.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-09 | IMG_8334.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-10 | IMG_8530.HEIC | HEIC→JPEG | 4032×3024 | camera photo |
| img-11 | IMG_8531.PNG | PNG (as-is) | 1284×2778 | **screenshot, not a camera photo — confirm keep/drop** |

## Flags for the human / harness

- **img-11 is an iPhone screenshot** (1284×2778 portrait), not a camera food photo like the
  other ten. It may be intentional (a menu/label screenshot as a harder case) or a stray file.
  Confirm whether it belongs in the set — that decides whether this is a 10- or 11-image benchmark.
- **img-11 PNG is 7.7 MB** — over the vision API's ~5 MB/image limit; it must be compressed
  before submission even in the "uncompressed" arm.
- The full-res JPEGs (~1.6–2.8 MB) are under the API limit but are **source**, not the final
  arms — the harness owns resizing to compressed (~1000px) vs uncompressed.

## Status

Asset set complete: 11 images (`images/` + `originals/`) and 20 text descriptions
(`descriptions/descriptions.json`). Ready for the harness. Descriptions are a draft — edit before the run.
