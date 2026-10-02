# 06: The privacy documents name Langfuse

**What to build:** The privacy policy and the App Store privacy details say that Langfuse processes conversation content, profile data, food logs and meal photos, so that prod tracing can be turned on. An agent drafts the wording; Lee approves it before anything is published.

**Blocked by:** None (can start immediately)

**Owner:** `mealvana_endurance` agent.

**Status:** wording approved by Lee 2026-10-02; the website policy and the App Store label are still to be updated (outside this repo)

- [x] The privacy documents in the repo name Langfuse, what it receives and why
- [x] The App Store privacy details are checked against what is sent and any change needed is listed
- [x] Lee has approved the wording
- [x] Onboarding body copy is not edited

2026-10-02. Lee approved the wording. Still outside this repo: paste it into the website policy, update the App Store label (and `PrivacyInfo.xcprivacy`) per `app_store_privacy_details.md`. The account-deletion ruling is still open.

Spec: `.scratch/langfuse/spec.md`. Decisions: `docs/langfuse/pivot/REPORT.md`. Words: `CONTEXT.md`, "Judging Vana". Langfuse access: `secrets/langfuse.env`, the `langfuse` skill, CLI and MCP server. Hobby allows 30 API requests a minute; pace any setup script.

## Comments

2026-09-30. Drafted, marked proposed everywhere, nothing published.

- `docs/privacy/langfuse_privacy_wording.md`: the wording to paste into the website's privacy policy, and six things
  to confirm first.
- `docs/privacy/app_store_privacy_details.md`, section "Langfuse": what is sent, and the label changes needed. Two:
  declare User Content → Photos or Videos, and User Content → Other User Content (chat messages), both linked, App
  Functionality. The manifest (`PrivacyInfo.xcprivacy`) changes first; it is not edited yet.
- `docs/privacy/privacy_manifest_explanation.md`: a proposed row in the processor table.

Found while checking: the label already under-declares. Meal photos and chat messages reach our server and the model
provider today, the label says User Content is not collected, and neither Anthropic nor the Vercel AI Gateway is in
the processor table. Not caused by Langfuse.

Needs Lee: approve the wording; rule on whether deleting an account must also delete the athlete's Langfuse records.
