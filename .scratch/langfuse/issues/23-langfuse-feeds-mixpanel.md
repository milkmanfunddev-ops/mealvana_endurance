# 23: Langfuse feeds Mixpanel

**What to build:** Langfuse's observations and Scores arrive in Mixpanel under the same athlete identity the app uses. Two rulings from Lee come first: which Mixpanel project receives the export, and what happens for athletes who declined analytics, since the server-side export has no consent gate. Lee pastes the Mixpanel token into Langfuse's settings himself.

**Blocked by:** 22

**Owner:** Lee (with Xuan where named).

**Status:** rulings taken 2026-10-02; waits on 22, then an agent builds the consent tag and enables the export

- [x] Lee has ruled on the Mixpanel project and on athletes without analytics consent
- [ ] An athlete who declined analytics has no AI activity joined to them in Mixpanel
- [ ] The integration is enabled with the right region and token
- [ ] `[Langfuse] Observation` and `[Langfuse] Score` events appear in Mixpanel on a known athlete's profile

2026-10-02, Lee: the Mixpanel token is in `.env.prod.local` / `.env.dev.local` (`MIXPANEL_PROJECT_TOKEN`), not pasted by hand. The two rulings (which project; athletes without analytics consent) are still open, and the ticket waits on 22.

2026-10-02, Lee's rulings:
1. The export goes to the **dev** Mixpanel project (`MIXPANEL_PROJECT_TOKEN` in `.env.dev.local`): we are testing on dev. Switching to prod later is a token change in Langfuse's Mixpanel settings.
2. Athletes who declined analytics: option (b). Each Turn's root carries the athlete's analytics consent as metadata, and Langfuse's export sends only consented athletes. Lee's weight on this: low ("I don't care too much about Mixpanel"), so this ticket is small and never blocks anything.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
