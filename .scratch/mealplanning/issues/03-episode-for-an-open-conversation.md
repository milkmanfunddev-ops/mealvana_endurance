# 03: An episode for a conversation still in progress

**Status:** done (2026-09-10) — `vana-chat` and `jade-chat` deployed to dev
**Blocked by:** None
**Next:** nothing. `vana-action` and `vana-day-notes` bundle the changed `memory.ts` but never touch
episodes; they pick it up on their next deploy.

**What to build:** The history cap's episode prepend, made real. `capHistory` already replays the last
twenty messages and prepends the conversation's episode sentence when the cap bites, and it is tested.
It has never once fired, because an episode is only written by lazy extraction and extraction only
ever reads a conversation the athlete is *not* in. So past twenty messages the front is dropped with
nothing in its place — the outcome the mechanism exists to prevent.

The cheapest shape: when the cap first bites, run the extractor's episode half over the messages about
to be dropped, in the background, and let the next turn pick it up. One Haiku call per conversation
that crosses twenty messages.

**Why it comes before the sheet.** A conversation past twenty messages is mostly a sheet-era
scenario — one ambient conversation per person per day, returned to all day. That is an argument for
building this *before* the sheet, not after: the sheet is what will start producing the conversations
this protects.

- [x] Server seam: a 21-message conversation with no episode writes one in the background and does not delay the reply
- [x] Server seam: the next turn prepends it, and the turn after that does not write a second one
- [x] The episode written mid-conversation is the same keyed row lazy extraction would later write, not a second one
- [x] A conversation that never crosses the cap writes nothing
- [x] Live eval: a long conversation stays coherent about something said in its first few turns
  (`long-conversation-remembers-its-start`, 1/1 on dev after the fix below)

**What was built.** `replayHistory` in `chat.ts` replaces the known-gap block: past the cap with no
episode, it hands `writeOpenEpisode` (`extract.ts`) to `waitUntil` and replays without one; the next
turn finds it. Tests: `supabase/functions/tests/vana/open_episode.test.ts`.

- **It reads the opening half of the transcript.** Not only the rows dropped that turn: at the
  crossing that is one row, usually Vana's first line. And not the whole transcript: the first live
  run fed it everything and got *"Discussed breakfast, lunch, protein targets, lentil dinners…"*, a
  list of the recent topics with the opening gone, and the eval failed. From the opening half, with a
  prompt that asks for names and numbers, it wrote *"Planning Saturday's four-hour ride with Marco;
  mid-ride camping stove stop; …"* and the eval passed. Past roughly forty messages the front is lost
  again, which the ticket's one-call-per-conversation budget accepts.
- **It never stamps `read_back_at`.** The conversation's margin notes are still owed; lazy extraction
  later rewrites the same episode row from the finished transcript.
- **It never overwrites.** If lazy extraction or a concurrent turn wrote an episode while the model
  was thinking, that one stands.
- **No index keeps an episode unique** (review finding): two racing writers can leave two rows, and
  `maybeSingle` errors on two, which used to cost the episode for good. Episode reads now take the
  newest row. A partial unique index on `(user_id, key) where kind = 'episode'` would close the race;
  it is a schema change, so it was left out.
- A failed model call writes no `vana_calls` row, so the `vana.episode` rate limit does not count it;
  the chat limit (4 turns / 10 s) bounds the retries.
- The test fake's `maybeSingle` now errors on several rows, as PostgREST does.

**Full history:** `../archive/issues-2026-09-10/03-general-mode-reads-the-doll.md` and `14-episode-for-an-open-conversation.md`
