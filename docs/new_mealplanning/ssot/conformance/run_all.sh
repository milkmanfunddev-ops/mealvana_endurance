#!/usr/bin/env bash
# All three arms, in order; stops at the first red so the failing arm is the last thing on screen.
set -euo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$D/run_edge.sh"; "$D/run_prototype.sh"; "$D/run_dart.sh"
