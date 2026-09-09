# 06: Lazy extraction

**What to build:** An athlete mentions in passing that their partner is vegetarian, never says "remember", and the next conversation already knows. When a conversation opens, the person's most recent conversation not yet read back is fed to one Haiku call with the margin-note rule and a strict schema: zero to three Memory sentences and one episode sentence. Sentences are written through the deduped writer with source conversation; the episode is written as an episode Memory and may also fill the conversation's summary column for list previews. The conversation is marked read back so it is never extracted twice. Nothing is announced to the person. The opener's synthetic message is not part of the transcript and must not be relied on.

**Blocked by:** 05 Remember reliably

**Status:** ready-for-agent

- [ ] Server seam: a fixture transcript with two durable facts and one plan detail yields two Memories and one episode, and the plan detail is not written
- [ ] Server seam: a second run over the same conversation writes nothing
- [ ] Server seam: a transcript with nothing durable yields zero Memories and still one episode
- [ ] Extraction runs in the background of the opening request and never delays the reply
- [ ] Live eval: a fact said in passing appears as a Memory and is used in the next conversation
- [ ] No card or mention is produced for extracted Memories
