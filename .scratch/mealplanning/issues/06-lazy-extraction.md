# 06: Lazy extraction

**What to build:** An athlete mentions in passing that their partner is vegetarian, never says "remember", and the next conversation already knows. When a conversation opens, the person's most recent conversation not yet read back is fed to one Haiku call with the margin-note rule and a strict schema: zero to three Memory sentences and one episode sentence. Sentences are written through the deduped writer with source conversation; the episode is written as an episode Memory and may also fill the conversation's summary column for list previews. The conversation is marked read back so it is never extracted twice. Nothing is announced to the person. The opener's synthetic message is not part of the transcript and must not be relied on.

**Blocked by:** 05 Remember reliably

**Status:** built, live eval not run, migration not applied (2026-09-09)

- [x] Server seam: a fixture transcript with two durable facts and one plan detail yields two Memories and one episode, and the plan detail is not written
- [x] Server seam: a second run over the same conversation writes nothing
- [x] Server seam: a transcript with nothing durable yields zero Memories and still one episode
- [x] Extraction runs in the background of the opening request and never delays the reply
- [ ] Live eval: a fact said in passing appears as a Memory and is used in the next conversation
- [x] No card or mention is produced for extracted Memories

**Notes (2026-09-09).** `_shared/vana/extract.ts` holds the whole thing. Opening a conversation
fires `readBackPrevious` under `waitUntil`, before the model call, so the reply is never waiting on
it. The extractor claims a conversation by stamping `read_back_at` before spending anything, which
is what makes a second run a no-op and stops two concurrent openers paying twice; a failed model
call releases the claim so a transient outage does not cost the conversation its one reading.
Sentences go through the deduped writer from ticket 05, the episode is a keyed Memory, and the
episode also fills the conversation's `summary` column, which until now was read by client and
server and written by nothing.

The transcript is text only and begins with Vana's own first turn, because the opener's synthetic
user message is never stored. Nothing in the extractor depends on it.

Not done:
- The migration `20260909180000_vana_conversation_read_back.sql` adds `read_back_at` and its partial
  index. It has NOT been applied to dev. Until it is, the claim update matches nothing and
  extraction silently no-ops — apply it before running the live eval.
- The live eval line. Case `passing-fact-extracted` is in `scripts/vana-eval/personalization.ts`.

