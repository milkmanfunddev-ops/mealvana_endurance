# Privacy policy wording for Langfuse

**Status: DRAFT, awaiting Lee's approval. Nothing here is published.**

Written 2026-09-30 for langfuse ticket 06. Production tracing (ticket 22) waits on this being
approved and the policy at https://www.mealvana.io/privacy-policy being updated. The policy text
lives on the website, not in this repo, so this file holds the wording to paste.

## What changes

Langfuse is a service for reviewing what an AI assistant did. Once production tracing is on, our
server sends Langfuse a copy of each AI call it makes for an athlete. Langfuse stores it in the
United States. Lee and Xuan read these copies to find poor answers and improve them.

## Proposed wording

Add to the list of service providers:

> **Langfuse** (Langfuse GmbH, hosted in the United States). When you use Vana, describe a meal or
> photograph a meal, we keep a record of that request so we can review and improve the answers you
> get. The record is stored with Langfuse. It contains your account ID, what you wrote or
> photographed, what Vana replied, and the information from your account that Vana used to answer:
> your first name, dietary preferences and allergies, nutrition targets, workouts and races, notes
> Vana has saved about you, and your food logs and meal plans. Langfuse stores this for us and does
> not use it for advertising or to train AI models.

Add to the section on how AI features use data, if the policy has one, else beside the entry above:

> Records of AI requests are read by Mealvana staff to check answer quality. Automated checks also
> read them and score the answers. We do this to make Vana's advice more accurate.

Add to retention:

> Records of AI requests are kept by Langfuse for 30 days and then deleted.

## To confirm before publishing

- **Retention.** 30 days is the Hobby plan's history limit. A move to a paid plan lengthens it (90
  days on Core, 3 years on Pro), and the sentence must change with it.
- **Deletion requests.** Deleting an account does not yet delete that athlete's records in
  Langfuse. Either `delete-user` also calls Langfuse's delete for the user, or the policy relies on
  the 30-day expiry. Needs Lee's ruling; it is not in any ticket.
- **The "does not train AI models" sentence** rests on Langfuse's terms. Read them before
  publishing: https://langfuse.com/terms and https://langfuse.com/privacy.
- **Langfuse's legal name and location** as written above are from memory of their site and must be
  checked against their DPA.
- **Anthropic and the Vercel AI Gateway** already receive the same content to produce the answer.
  If the published policy does not name them, add them in the same edit (see
  `app_store_privacy_details.md`, "Langfuse").
- **Mixpanel export** (ticket 23) is a separate disclosure and is not covered here.
- Onboarding body copy is not changed by any of this.
