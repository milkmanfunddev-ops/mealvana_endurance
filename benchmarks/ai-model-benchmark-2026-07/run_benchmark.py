#!/usr/bin/env python3
"""
2x2 model-quality benchmark — {Haiku, Sonnet} x {compressed, uncompressed}.

Notion: "Run the 2x2 model-quality benchmark ... over the fixed asset set"
(3a7e3fdb754c81b0ae52dd88980d49ac).

Why this calls the AI Gateway directly instead of the edge functions:
`DESCRIBE_MEAL_MODEL` / `ANALYZE_MEAL_PHOTO_MODEL` are read from the process
environment at module load, so varying the model per call is impossible without
flipping a Supabase secret and redeploying between every arm. That would
disrupt dev four times, debit AI credits (now enforced), and hit function rate
limits. Instead this reproduces exactly what the functions send: the SAME
prompt text, the SAME JSON schema, the SAME max output tokens. The only thing
removed is auth/credit/storage plumbing, which cannot affect extraction
quality.

Prompts below are copied verbatim from:
  supabase/functions/describe-meal/index.ts
  supabase/functions/analyze-meal-photo/index.ts
Schema from:
  supabase/functions/_shared/meal_analysis/schema.ts
If those change, this file must be updated or the benchmark stops measuring
what ships.

Usage:  python3 run_benchmark.py            # full 2x2
        python3 run_benchmark.py --smoke    # 1 call per arm
"""

import base64
import json
import mimetypes
import pathlib
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

ROOT = pathlib.Path(__file__).resolve().parent
REPO = ROOT.parent.parent
GATEWAY = "https://ai-gateway.vercel.sh/v1/chat/completions"

MODELS = {
    "haiku": "anthropic/claude-haiku-4.5",
    "sonnet": "anthropic/claude-sonnet-4.6",
    "opus": "anthropic/claude-opus-5",
}
MAX_OUTPUT_TOKENS = 1000
CONCURRENCY = 6

# --------------------------------------------------------------------------
# Schema — mirrors MealAnalysisSchema (zod) as JSON Schema
# --------------------------------------------------------------------------

ITEM = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "portion": {"type": "string"},
        "calories": {"type": "integer", "minimum": 0},
        "carb_g": {"type": "number", "minimum": 0},
        "protein_g": {"type": "number", "minimum": 0},
        "fat_g": {"type": "number", "minimum": 0},
        "sodium_mg": {"type": "number", "minimum": 0},
    },
    "required": ["name", "portion", "calories", "carb_g", "protein_g",
                 "fat_g", "sodium_mg"],
    "additionalProperties": False,
}
TOTALS = {
    "type": "object",
    "properties": {
        "calories": {"type": "integer", "minimum": 0},
        "carb_g": {"type": "number", "minimum": 0},
        "protein_g": {"type": "number", "minimum": 0},
        "fat_g": {"type": "number", "minimum": 0},
        "sodium_mg": {"type": "number", "minimum": 0},
    },
    "required": ["calories", "carb_g", "protein_g", "fat_g", "sodium_mg"],
    "additionalProperties": False,
}
MEAL_ANALYSIS_SCHEMA = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "suggested_slot": {"type": "string",
                           "enum": ["breakfast", "lunch", "dinner", "snack"]},
        "confidence": {"type": "string", "enum": ["low", "medium", "high"]},
        "items": {"type": "array", "items": ITEM, "minItems": 1, "maxItems": 12},
        "totals": TOTALS,
        "notes": {"type": "string"},
    },
    "required": ["name", "suggested_slot", "confidence", "items", "totals"],
    "additionalProperties": False,
}

# --------------------------------------------------------------------------
# Prompts — verbatim from the edge functions
# --------------------------------------------------------------------------

DESCRIBE_PROMPT = """You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

The athlete described this meal: "{description}"

INSTRUCTIONS:
- Group food into items the way a person logging their own meal would think
  about it — one item per DISH or line, not one item per raw ingredient.
  For example: "spaghetti and meatballs" is ONE item (its sauce, pasta, and
  meatballs are summed into one entry), while a side of "broccoli" is a
  SEPARATE item because it's a distinct component of the plate. Similarly,
  "a turkey sandwich with lettuce and mayo" is ONE item, not three. Only
  split into multiple items when the foods are genuinely separate parts of
  the meal (a side dish, a drink, a dessert) — never split a single dish's
  own ingredients apart.
- Each item's macros must be the SUM across everything that makes up that
  dish (e.g. the meatballs' and sauce's calories/carbs/protein/fat/sodium
  are combined into the "spaghetti and meatballs" item, not reported
  separately).
- If a quantity is mentioned (e.g. "two eggs", "large OJ"), use it; otherwise assume a single, realistic serving for an adult endurance athlete.
- Do NOT underestimate portions — athletes eat meaningfully sized meals.
- Provide per-item macros: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg). These must be non-null for every item.
- Compute accurate totals across all items.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods described.
- Set confidence to "high" if the description is precise (weights, brand names, counts); "medium" if typical portions can be inferred; "low" if too vague to estimate reliably.
- If the description clearly does not describe food (e.g. a movie title, a random sentence), set confidence to "low", return a single placeholder item, and set notes to explain.

Return your answer as structured JSON matching the requested schema."""

PHOTO_PROMPT = """You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

Analyze this food photo and return a structured meal breakdown.

INSTRUCTIONS:
- Group what you see into items the way a person logging their own plate
  would think about it — one item per DISH, not one item per raw
  ingredient. For example: a plate of "spaghetti and meatballs" is ONE
  item (its sauce, pasta, and meatballs summed into one entry), while a
  side of "broccoli" on the same plate is a SEPARATE item because it's a
  distinct component of the meal. Only split into multiple items when the
  foods are genuinely separate parts of the plate (a side dish, a drink, a
  dessert) — never split a single dish's own ingredients apart.
- Each item's macros must be the SUM across everything that makes up that
  dish (e.g. the meatballs' and sauce's calories/carbs/protein/fat/sodium
  are combined into the "spaghetti and meatballs" item, not reported
  separately).
- Estimate realistic portions for an adult endurance athlete — do NOT underestimate. If there is a full plate of pasta, estimate the full plate, not a small serving.
- Provide per-item macros: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg). These must be non-null for every item.
- Compute accurate totals across all items.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods visible.
- Set confidence to "low" if the image is blurry, partially visible, or ambiguous; "medium" if items are visible but portions are uncertain; "high" if clear and well-portioned.
- If the image clearly does not contain food (e.g. a landscape, a person's face, a document), do NOT return a meal analysis — instead return a JSON object with a single field: { "not_food": true }.

Return your answer as structured JSON matching the requested schema."""

# --------------------------------------------------------------------------
# Gateway call
# --------------------------------------------------------------------------


def api_key() -> str:
    env = (REPO / "secrets" / "ai_gateway.env").read_text()
    return re.search(r"^AI_GATEWAY_API_KEY=(.+)$", env, re.M).group(1).strip().strip("\"'")


KEY = api_key()


def call(model: str, content, tag: str) -> dict:
    """One gateway call. curl, not urllib — urllib gets Cloudflare-1010'd."""
    payload = {
        "model": model,
        "max_tokens": MAX_OUTPUT_TOKENS,
        "messages": [{"role": "user", "content": content}],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "meal_analysis",
                "strict": True,
                "schema": MEAL_ANALYSIS_SCHEMA,
            },
        },
    }
    body = json.dumps(payload)
    t0 = time.time()
    proc = subprocess.run(
        ["curl", "-s", "--max-time", "180", GATEWAY,
         "-H", f"Authorization: Bearer {KEY}",
         "-H", "Content-Type: application/json",
         "--data-binary", "@-"],
        input=body, capture_output=True, text=True,
    )
    latency = time.time() - t0

    out = {"tag": tag, "model": model, "latency_s": round(latency, 2)}
    try:
        d = json.loads(proc.stdout)
    except Exception:
        out["error"] = f"unparseable response: {proc.stdout[:200]}"
        return out
    if "error" in d:
        out["error"] = str(d["error"])[:300]
        return out

    usage = d.get("usage") or {}
    out["input_tokens"] = usage.get("prompt_tokens")
    out["output_tokens"] = usage.get("completion_tokens")
    try:
        out["analysis"] = json.loads(d["choices"][0]["message"]["content"])
    except Exception as e:
        out["error"] = f"bad JSON payload: {e}"
    return out


def image_content(path: pathlib.Path):
    mime = mimetypes.guess_type(path.name)[0] or "image/jpeg"
    b64 = base64.b64encode(path.read_bytes()).decode()
    return [
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
        {"type": "text", "text": PHOTO_PROMPT},
    ]


# --------------------------------------------------------------------------
# Run matrix
# --------------------------------------------------------------------------


def build_jobs(smoke: bool, images_only: bool = False, rep: int = 0,
               only: str | None = None):
    jobs = []
    models = {only: MODELS[only]} if only else MODELS
    if images_only:
        for arm in ("compressed", "uncompressed"):
            imgs = sorted((ROOT / "_derived" / arm).glob("*.jpg"))
            for mkey, model in models.items():
                for p in imgs:
                    jobs.append((f"image|{mkey}|{arm}|{p.stem}|r{rep}", model,
                                 image_content(p)))
        return jobs
    descs = json.loads((ROOT / "descriptions" / "descriptions.json").read_text())
    text_items = [(f"{k}-{d['id']}", d) for k in ("long", "short") for d in descs[k]]
    if smoke:
        text_items = text_items[:1]
    for mkey, model in models.items():
        for tag, d in text_items:
            jobs.append((f"text|{mkey}|{d['id']}", model,
                         DESCRIBE_PROMPT.format(description=d["text"])))

    for arm in ("compressed", "uncompressed"):
        imgs = sorted((ROOT / "_derived" / arm).glob("*.jpg"))
        if smoke:
            imgs = imgs[:1]
        for mkey, model in models.items():
            for p in imgs:
                jobs.append((f"image|{mkey}|{arm}|{p.stem}", model,
                             image_content(p)))
    return jobs


def main():
    smoke = "--smoke" in sys.argv
    images_only = "--images-only" in sys.argv
    rep = int(sys.argv[sys.argv.index("--rep") + 1]) if "--rep" in sys.argv else 0
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    jobs = build_jobs(smoke, images_only, rep, only)
    print(f"running {len(jobs)} calls (concurrency {CONCURRENCY})…", flush=True)

    results = []
    done = 0
    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(call, m, c, t): t for t, m, c in jobs}
        for f in futs:
            pass
        for f, tag in futs.items():
            r = f.result()
            r["tag"] = tag
            results.append(r)
            done += 1
            status = "ERR " + r["error"][:60] if "error" in r else "ok"
            print(f"  [{done}/{len(jobs)}] {tag}  {r['latency_s']}s  {status}",
                  flush=True)

    name = ("results_smoke.json" if smoke
            else f"results_{only}.json" if only
            else f"results_images_r{rep}.json" if images_only else "results.json")
    out = ROOT / "_derived" / name
    out.write_text(json.dumps(results, indent=2))
    print(f"\nwrote {out}")
    errs = [r for r in results if "error" in r]
    print(f"ok: {len(results) - len(errs)}   errors: {len(errs)}")


if __name__ == "__main__":
    main()
