# 14: An episode for a conversation still in progress

**Status:** ready-for-agent
**Blocked by:** None
**Next:** Run `/mattpocock-skills:implement 14`.

**What to build:** The history cap's episode prepend, made real. `capHistory` already replays the last
twenty messages and prepends the conversation's episode sentence when the cap bites, and it is tested.
It has never once fired, because an episode is only written by lazy extraction and extraction only
ever reads a conversation the athlete is *not* in. So past twenty messages the front is dropped with
nothing in its place — the outcome the mechanism exists to prevent.

The cheapest shape: when the cap first bites, run the extractor's episode half over the messages about
to be dropped, in the background, and let the next turn pick it up. One Haiku call per conversation
that crosses twenty messages.

- [ ] Server seam: a 21-message conversation with no episode writes one in the background and does not delay the reply
- [ ] Server seam: the next turn prepends it, and the turn after that does not write a second one
- [ ] The episode written mid-conversation is the same keyed row lazy extraction would later write, not a second one
- [ ] A conversation that never crosses the cap writes nothing
- [ ] Live eval: a long conversation stays coherent about something said in its first few turns
