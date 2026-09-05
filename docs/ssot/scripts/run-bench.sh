#!/usr/bin/env bash
#
# run-bench.sh — run the 30-scenario benchmark corpus through the DEV edge functions
# and record where each phase's selection resolved (step 1/2/3/4 of the food-recommendation
# cascade, spec/fueling/food-recommendation.md §1 + §10).
#
# ─── WHAT IT DOES ────────────────────────────────────────────────────────────
#   For each scenario in bench/scenarios.json:
#     1. POST generate-macros-v4        → macro targets (+ pre_run_selections)
#     2. POST generate-nutrition-plan-v3 → the food plan
#     3. Record generation_path × pin_decision → step, per phase, plus the picked foods.
#   Output: bench/results-<env>-<stamp>.json  +  a printed funnel table.
#
#   READ-ONLY on the catalog; it does create one plan_generation_log row per call.
#   Every device_id is prefixed BENCH- so those rows are identifiable as synthetic
#   (the ruled x-mealvana-test marker does not exist until this bundle lands).
#
# ─── HOW TO RUN ──────────────────────────────────────────────────────────────
#   ! scripts/run-bench.sh [dev|prod] [label]
#   Claude: needs Bash(scripts/run-bench.sh:*)
#
set -euo pipefail
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
QA_ROOT="$SCRIPT_DIR/.."
ENV_SEL="${1:-dev}"
LABEL="${2:-baseline}"

python3 "$QA_ROOT/scripts/bench.py" "$MV_ROOT" "$QA_ROOT" "$ENV_SEL" "$LABEL"
