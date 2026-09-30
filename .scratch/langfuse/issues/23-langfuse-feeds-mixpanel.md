# 23: Langfuse feeds Mixpanel

**What to build:** Langfuse's observations and Scores arrive in Mixpanel under the same athlete identity the app uses. Two rulings from Lee come first: which Mixpanel project receives the export, and what happens for athletes who declined analytics, since the server-side export has no consent gate. Lee pastes the Mixpanel token into Langfuse's settings himself.

**Blocked by:** 22

**Owner:** Lee (with Xuan where named).

**Status:** ready-for-human

- [ ] Lee has ruled on the Mixpanel project and on athletes without analytics consent
- [ ] An athlete who declined analytics has no AI activity joined to them in Mixpanel
- [ ] The integration is enabled with the right region and token
- [ ] `[Langfuse] Observation` and `[Langfuse] Score` events appear in Mixpanel on a known athlete's profile

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.
