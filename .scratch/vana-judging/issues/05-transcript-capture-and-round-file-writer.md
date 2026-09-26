# 05: Transcript capture and round-file writer

**What to build:** The plumbing that turns a finished conversation into judging data. A small
script that, given an account and a conversation, pulls the server-persisted transcript (both
sides of every turn, tool calls, metadata) and writes it under `/eval/runs/`; and the round-file
writer that assembles a round's results as the pair every round produces: a human-readable
markdown file and a structured JSON sidecar carrying per-Run Marks, dimension breakdowns,
verdict text, and Improvement links — the exact shape the future visual artifact will render
from. Mark values are supplied by the Examiner; this ticket builds where they land, not the
judging itself.

**Blocked by:** 01 (scaffold — runs/ and the sidecar convention live there).

**Status:** ready-for-agent

- [ ] Given a conversation, the script emits its full transcript (user turns, Vana turns, tool
      calls, parts) to a file under `/eval/runs/`
- [ ] The round-file writer produces both the prose file and the JSON sidecar from one input
- [ ] The JSON sidecar schema is documented in the README (round, scenario, account, marks per
      dimension, weighted Mark, verdict, improvement references, robotic-cap flag if applied)
- [ ] Verified end-to-end against a real existing conversation on dev
