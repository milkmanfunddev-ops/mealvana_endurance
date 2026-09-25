# 111-004 · netcut cannot cut a request that reuses an open keep-alive socket, so the first offline tap still reaches the server

- kind: idea
- status: open
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Idea for the harness (IMPROVEMENTS #36). During 21-007, `netcut.sh on` at 21:14:51Z and Connect Kroger tapped at once: the `connect` call reached the server (`kroger_oauth_sessions` 14146c21 written 21:14:52Z) and the kroger.com alert opened; `netcut.log` had no line. The app reused an HTTP keep-alive socket opened before the cut, and netcut blocks only new connects. After 40 s idle, the retry was blocked and the app showed "Kroger could not be reached". Make `netcut.sh on` also shut down open sockets (or tell the runbook to wait ~30 s after `on`), so an offline check does not pass or fail on socket reuse.

**Expected.**


**Actual.**


**Evidence.**
- runs/111/notes.md (21-007 lines)
- runs/111/27-21-007-offline-connect-retry.png

**Decision quote.**
> 

**Triage.**
