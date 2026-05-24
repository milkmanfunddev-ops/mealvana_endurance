#!/usr/bin/env bash
# Deploy one or more Supabase edge functions to the DEV project.
#
# Why this wrapper exists:
#   `supabase functions deploy` defaults to whatever project ref is currently
#   linked in `supabase/.temp/project-ref`. That file can silently point at
#   prod after any `supabase link` call (and as of 2026-05-23 the committed
#   value IS prod). This wrapper sidesteps that by reading the target ref
#   directly from `.env.dev.local` (SUPABASE_URL) and passing `--project-ref`
#   explicitly.
#
# Usage:
#   ./scripts/deploy_dev.sh generate-macros-v4
#   ./scripts/deploy_dev.sh generate-macros-v4 generate-nutrition-plan-v3
#
# Requires:
#   - .env.dev.local with SUPABASE_URL=https://<ref>.supabase.co
#   - $SUPABASE_ACCESS_TOKEN env var OR ~/.supabase/pat

set -euo pipefail

ENV_FILE=".env.dev.local"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "error: $ENV_FILE not found (run from repo root)" >&2
  exit 1
fi

PROJECT_REF=$(grep -E '^SUPABASE_URL=' "$ENV_FILE" | head -1 | cut -d/ -f3 | cut -d. -f1)
if [[ -z "$PROJECT_REF" ]]; then
  echo "error: could not parse SUPABASE_URL from $ENV_FILE" >&2
  exit 1
fi

# Per memory note: ~/.supabase/pat is the canonical PAT source. Always prefer
# the file over an inherited env var, because a stale env var (e.g., from a
# zshrc export written months ago) will silently 401 every API call.
if [[ -r "$HOME/.supabase/pat" ]]; then
  export SUPABASE_ACCESS_TOKEN="$(tr -d '[:space:]' < "$HOME/.supabase/pat")"
elif [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "error: ~/.supabase/pat not found and \$SUPABASE_ACCESS_TOKEN unset" >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <function-name> [<function-name> ...]" >&2
  exit 2
fi

echo "→ Target: DEV ($PROJECT_REF)"
for fn in "$@"; do
  echo "→ Deploying $fn..."
  supabase functions deploy "$fn" --project-ref "$PROJECT_REF"
done
echo "✓ Done."
