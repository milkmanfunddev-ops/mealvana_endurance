#!/usr/bin/env bash
# Deploy one or more Supabase edge functions to the PROD project.
#
# Why this wrapper exists: same as deploy_dev.sh — `supabase functions deploy`
# trusts `supabase/.temp/project-ref` which can silently drift. This wrapper
# reads the prod ref from `.env.prod.local` and passes `--project-ref`
# explicitly. It also REQUIRES interactive `yes` confirmation before each
# run so prod deploys can't happen by accident.
#
# Usage:
#   ./scripts/deploy_prod.sh generate-macros-v4
#   ./scripts/deploy_prod.sh generate-macros-v4 generate-nutrition-plan-v3
#
# Requires:
#   - .env.prod.local with SUPABASE_URL=https://<ref>.supabase.co
#   - $SUPABASE_ACCESS_TOKEN env var OR ~/.supabase/pat

set -euo pipefail

ENV_FILE=".env.prod.local"
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

echo
echo "  ⚠️  DEPLOYING TO PROD: $PROJECT_REF"
echo "  Functions: $*"
echo
read -r -p "  Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "aborted." >&2
  exit 1
fi

for fn in "$@"; do
  echo "→ Deploying $fn..."
  supabase functions deploy "$fn" --project-ref "$PROJECT_REF"
done
echo "✓ Done."
