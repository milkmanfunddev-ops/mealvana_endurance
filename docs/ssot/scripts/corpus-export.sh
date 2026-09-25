#!/usr/bin/env bash
# corpus-export — pull novel de-identified exemplars into the QA corpus
# (real-payload-corpus@v1, L-7 item 5).
#
# The samples directory IS the append-only registry: existing file names are
# the known fingerprint ids, sent to the server so only NOVEL shapes come
# back — already-scrubbed server-side (raw never leaves the server
# un-scrubbed). Exemplars are FROZEN: this script refuses to overwrite, ever.
#
#   ./scripts/corpus-export.sh [dev|prod]             # default dev
#   ./scripts/corpus-export.sh [dev|prod] --rescrub   # correction path
#
# --rescrub is the SANCTIONED frozen-exemplar correction path: the intake
# allows touching an existing exemplar only "to correct it (re-scrub if the
# de-id standard tightens, or fix a discovered leak)". It re-emits exactly the
# fingerprints already on disk through the CURRENT scrubber and overwrites
# them in place — same fingerprints, clean content. It never adds new
# exemplars, and the normal mode still refuses to overwrite anything.
#
# Requires: CORPUS_EXPORT_TOKEN env var (the function's shared secret),
# python3. Provenance is stamped per file; the sandbox-host + hand-typed
# stamp for the 2026-09 seed specimens is a standing requirement (qa-70).

set -euo pipefail
find_workspace() { local d="$1"; while [ "$d" != "/" ]; do
  [ -f "$d/workspace.env" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MV_ROOT="$(find_workspace "$SCRIPT_DIR")"
[ -n "$MV_ROOT" ] || { echo "ABORT: workspace.env not found"; exit 1; }
source "$MV_ROOT/workspace.env"

ENV="${1:-dev}"
MODE="${2:-export}"
case "$ENV" in
  dev)  REF="vlmtsdzpnjnavdgytcmi" ;;
  prod) REF="$(grep -E '^SUPABASE_URL=' "$APP_ROOT/.env.prod.local" | cut -d/ -f3 | cut -d. -f1)" ;;
  *) echo "usage: $0 [dev|prod]"; exit 2 ;;
esac
: "${CORPUS_EXPORT_TOKEN:?set CORPUS_EXPORT_TOKEN}"

SAMPLES="$QA_ROOT/vectors/integrations/samples"
mkdir -p "$SAMPLES"

QA_SAMPLES="$SAMPLES" REF="$REF" ENV_NAME="$ENV" MODE="$MODE" python3 - <<'PY'
import json, os, glob, urllib.request, datetime

samples = os.environ["QA_SAMPLES"]
rescrub = os.environ.get("MODE") == "--rescrub"


def _env_of(path):
    """Which environment produced this exemplar (legacy files predate the
    stamp and are all dev)."""
    try:
        prov = json.load(open(path))["provenance"]
        if "environment" in prov:
            return prov["environment"]
        # Legacy files predate the explicit stamp; their note already says
        # which material they are, and only prod stamps carry "(prod)".
        return "prod" if "(prod)" in prov.get("note", "") else "dev"
    except Exception:
        return "dev"


_all_files = glob.glob(os.path.join(samples, "*", "*.json"))
# In rescrub mode the registry is scoped to this environment's own material;
# in normal mode every known id is sent so nothing is re-promoted.
known = sorted(
    os.path.splitext(os.path.basename(p))[0]
    for p in _all_files
    if not rescrub or _env_of(p) == os.environ["ENV_NAME"]
)
req = urllib.request.Request(
    f"https://{os.environ['REF']}.supabase.co/functions/v1/corpus-export",
    data=json.dumps(
        {"rescrubIds": known} if rescrub else {"known": known}
    ).encode(),
    headers={
        "Content-Type": "application/json",
        "x-export-token": os.environ["CORPUS_EXPORT_TOKEN"],
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as r:
    out = json.loads(r.read().decode())

if rescrub:
    print(f"   RE-SCRUB: {out['scanned']} raw rows scanned; "
          f"{len(out['exemplars'])} of {len(known)} exemplars re-emitted")
    if len(out["exemplars"]) != len(known):
        raise SystemExit(
            "REFUSED: re-scrub did not return every known exemplar — the raw "
            "rows behind the missing ones may have aged out past the 90-day "
            "TTL. Re-scrub only what the server can still produce."
        )
else:
    print(f"   scanned {out['scanned']} raw rows; known {len(known)}; "
          f"novel {len(out['exemplars'])}")
for e in out["exemplars"]:
    # Provenance is resolved SERVER-SIDE from the source material (the
    # environment + how the values arose), so account ids never leave the
    # server. Fail closed: unknown material refuses to write.
    if not e.get("sourceMaterial"):
        raise SystemExit(
            f"REFUSED: no provenance stamp for the source material behind "
            f"{e['fingerprintId']} ({e['provider']}) — add it to "
            "SOURCE_MATERIAL in the corpus-export function before promoting. "
            "An exemplar with an inaccurate stamp is worse than no exemplar."
        )
    d = os.path.join(samples, e["provider"])
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, e["fingerprintId"] + ".json")
    if os.path.exists(path) and not rescrub:
        raise SystemExit(f"REFUSED: exemplar exists (frozen): {path}")
    doc = {
        "fingerprintId": e["fingerprintId"],
        "provider": e["provider"],
        "stratum": e["stratum"],
        "optionalKeysInStratum": e["optionalKeysInStratum"],
        "provenance": {
            "source": f"{os.environ['ENV_NAME']} provider_raw_payloads",
            "scrubbed": "server-side (corpus-export edge fn)",
            "environment": os.environ["ENV_NAME"],
            "exportedAt": datetime.datetime.now(datetime.timezone.utc)
                .isoformat(timespec="seconds"),
            "note": e["sourceMaterial"],
            **({"correction": "re-scrubbed under the default-deny standard "
                              "(@v1.1 samples de-id erratum, ruled 2026-09-20); "
                              "fingerprint unchanged, content re-destroyed"}
               if rescrub else {}),
        },
        "exemplar": e["exemplar"],
        # Linked payloads this exemplar references (its parent, or its
        # children), scrubbed in the SAME context so the synthetic ids
        # resolve within this file. Context, never registry entries.
        **({"linkedCompanions": e["linkedCompanions"]}
           if e.get("linkedCompanions") else {}),
    }
    with open(path, "w") as f:
        json.dump(doc, f, indent=1, sort_keys=False)
        f.write("\n")
    print(f"   {'RE-SCRUBBED' if rescrub else 'NEW'}: "
          f"{os.path.relpath(path, samples)}")
PY
