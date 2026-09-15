# Conversation memory strategies for Vana

Note: `docs/research/` did not exist before this file; this is the repo's first research note. Feeds `.scratch/mealplanning/decisions.md` mp-217. Researched 2026-09-14 from primary sources only; every claim carries the URL that owns it.

## The question

How do production chat assistants carry context within a conversation and across conversations, and what does it cost? Four parts: the verbatim window, summarisation, long-term memory, and prompt caching.

## Comparison of approaches

| Approach | What is kept | When it runs | Who has shipped it | Cost per turn effect | Failure modes |
|---|---|---|---|---|---|
| Verbatim window | The last N messages or last T tokens, unchanged | Every turn, before the model call | LangChain `trim_messages` with `strategy="last"` ([docs](https://docs.langchain.com/oss/python/langchain/short-term-memory)); LlamaIndex flushes the oldest `token_flush_size` (default 3000) once history passes `chat_history_token_ratio` (0.7) of `token_limit` (30000) ([docs](https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/memory/)); OpenAI `previous_response_id` chains bill all prior input tokens each turn ([docs](https://developers.openai.com/api/docs/guides/conversation-state)) | Bounded input; a sliding window shifts the prefix every turn, which defeats a prefix cache (see caching row) | Whatever fell off is gone; the model loses the conversation's opening |
| Rolling summary (mid-conversation) | A summary message plus the last K verbatim messages | When a threshold trips, before the model call | LangChain `SummarizationMiddleware`: `keep=("messages", 20)`, summary inserted as a `HumanMessage` "Here is a summary of the conversation to date", runs in `before_model` ([source](https://raw.githubusercontent.com/langchain-ai/langchain/master/libs/langchain_v1/langchain/agents/middleware/summarization.py)); Anthropic SDK `compactionControl` at `contextTokenThreshold` 100000, now deprecated in favour of server-side ([docs](https://platform.claude.com/docs/en/build-with-claude/context-editing)); OpenAI server-side compaction via `context_management.compact_threshold` returns an opaque compaction item ([docs](https://developers.openai.com/api/docs/guides/compaction)); Character.AI "tidies older context in the background and keeps what matters" ([blog](https://blog.character.ai/memory/)) | One extra model call per threshold crossing, then a shorter prefix | Summary written from the wrong slice loses the opening (Vana hit this, mp-034); summary quality is unverifiable; each rewrite invalidates the cache after it |
| End-of-conversation summary | One sentence or paragraph per conversation | After the conversation ends, or lazily when the next one opens | Vana's episode row (this repo); Claude moved away from it: "saves memory as a set of individual topics as you chat, rather than summarizing conversations after they end" ([help center](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context)) | One call per conversation | A chat has no clear end; the next conversation may open before the summary exists and then waits or goes without |
| Extracted memory notes | Short facts about the person, keyed and editable | In the hot path (model writes them during the chat) or in the background | ChatGPT: "saved memories" the user asked for plus "chat history" insights it gathers itself ([OpenAI](https://openai.com/index/memory-and-new-controls-for-chatgpt/), read via search index; page returns 403 to fetch); Claude: individual categorised entries updated as you chat, one memory per project, sensitive topics off by default ([help center](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context), [blog](https://claude.com/blog/memory)); Character.AI "Facts picks them up as you chat and saves them automatically" ([blog](https://blog.character.ai/memory/)); LangChain store with namespaces, written from tools in the hot path via `store.put()` ([docs](https://docs.langchain.com/oss/python/langchain/long-term-memory)); LlamaIndex `FactExtractionMemoryBlock` condenses flushed history into facts ([docs](https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/memory/)) | A few hundred tokens injected per turn; extraction cost is a tool call (hot path) or one call per batch (background) | Model forgets to call the tool; extractor stores schedule instead of person (mp-038); duplicates without a dedupe rule |
| Retrieval by embedding | All past messages or notes, fetched by similarity | Per turn, or on demand as a tool | Claude chat search "uses Retrieval-Augmented Generation (RAG) and will appear as tool calls" ([help center](https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context)); LangChain `store.search()`; LlamaIndex `VectorMemoryBlock` | One embedding call plus the tokens of what is fetched | Fetches the wrong thing; a tool the model may skip is not personalisation (mp-019) |
| Prompt caching | The unchanged prefix (tools, system, earlier messages) is billed at a discount | Every turn, automatically once markers are set | Anthropic: 5 min write 1.25x, 1 h write 2x, read 0.1x; Haiku 4.5 minimum 4,096 tokens; order is tools then system then messages; automatic caching moves the breakpoint forward as the conversation grows ([docs](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)); OpenAI reads cost 0.1x on GPT-5.6+, 1,024 token minimum, "reusing the growing conversation history can save more input tokens than caching only the initial instructions" ([docs](https://developers.openai.com/api/docs/guides/prompt-caching)); Character.AI keeps an average 180-message history and reaches a 95% cache rate ([blog](https://blog.character.ai/optimizing-ai-inference-at-character-ai-2/)); Vercel AI Gateway `caching: 'auto'` adds two Anthropic breakpoints, last message and the message before the last user message, 5 min TTL ([docs](https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching)) | Input cost drops to roughly a tenth for the cached part; break-even is one read | Prefix under the model minimum caches nothing silently; any change before the breakpoint (a rewritten context block, a slid window) invalidates everything after it; entries expire after 5 minutes |

Inflection Pi: the only first-party page found says Pi Journeys "remembers the people you actually mention" and "You can see and edit every note, anytime" ([inflection.ai](https://inflection.ai/labs/pi-journeys)). No Inflection source describes the mechanism. Not asserted further.

## What Mealvana does today

Every turn rebuilds the system prompt as persona plus a fresh `CONTEXT` block (`chat.ts` `systemPrompt`); the planning persona measures about 2,700 tokens and the general one about 1,100 at four characters per token, and 32 tool definitions ride along. `replayHistory` in `supabase/functions/_shared/vana/chat.ts` sends the last `HISTORY_CAP = 20` messages verbatim and, once the cap bites, prepends "Earlier in this conversation: {episode}" as a user message. When the cap first bites with no episode, `writeOpenEpisode` in `extract.ts` runs a Haiku call in the background over the opening half of the transcript and the next turn picks the sentence up. Opening a conversation feeds the newest unread previous conversation to one extractor call that writes zero to three margin notes and one episode, and the scripted opener waits up to `OPENER_READ_BACK_MS = 3500` for it (mp-009, rejected). No `cache_control` marker and no `caching: 'auto'` is set anywhere under `_shared/vana/`, so every turn pays full input price for the whole prompt.

## Recommendation for a Haiku-class assistant on Supabase edge functions with an offline-first Flutter client

1. Turn caching on first. Add `providerOptions.gateway.caching: 'auto'` to the `streamText` call, or explicit `cacheControl` on the persona block and the last message ([AI SDK](https://ai-sdk.dev/providers/ai-sdk-providers/anthropic)). Read `usage.inputTokenDetails.cacheReadTokens` in `onFinish` and log it to `vana_calls`. Zero cached tokens means the prefix is under 4,096 or something before the breakpoint changed.

2. Make the prefix stable. Order is tools, persona, context, messages. Split the system prompt into two text blocks: persona (static) and context. Assemble the context block once per conversation open and reuse it for the conversation's turns; refresh it only when a tool writes (plan, memory, pantry) or the day changes. Move per-message `recallMemories` out of the block and into the user message tail, or drop it: `listNotes(10)` and `recentEpisodes(3)` already cover the person. This is the point of mp-020 and mp-218: a short block, and a block that does not change every turn.

3. Replace the sliding cap with chunked compaction. A sliding window changes the first replayed message every turn and invalidates the cache from that point. Keep every message verbatim until 40, then replace the oldest 20 with one summary message and keep the last 20. The summary is written from the messages being dropped plus the previous summary (rolling), in the background when the count reaches 30, and applied at 40, so no turn ever waits and the prefix only changes once per 20 turns. This is LangChain's shape (`keep` 20) with a background writer. Store the summary on `vana_conversations.summary`, keyed by the message index it covers, which closes the race in mp-036 without a new table.

4. Drop the read-back-on-open and the 3.5 second wait. Two moves replace it. Hot path: the persona already has a `rememberFact` rule; sharpen it so the model saves a margin note the moment the athlete says something durable, the way Claude "saves memory as a set of individual topics as you chat". Safety net: a `pg_cron` sweep every 15 minutes that extracts conversations idle for 30 minutes and unread. mp-026 rejected cron as extra plumbing; it is less plumbing than the opener wait, `readBackWithin`, and `athleteWordsFrom` combined, and it means the summary exists before the next conversation opens, which is what mp-217 asks for. The opener reads what the memory table holds and never waits.

5. Keep episodes, keep LAST TALKS. Three episode sentences newest first is a cheap cross-conversation bridge, and the "what they said, not their schedule" framing (mp-038) stays. Embedding recall stays as a tool for "what did we say about X", not a per-turn block.

Trade-offs. Caching entries live five minutes; an athlete who replies after a coffee pays one 1.25x write again, which is still cheaper than today's every-turn full price. The 1 h TTL costs 2x to write and only pays off if a conversation commonly pauses over five minutes; measure before switching. Chunked compaction means a conversation between 21 and 40 messages carries more tokens than today; caching makes those tokens cost a tenth. Hot-path memory depends on the model calling the tool; the cron sweep catches what it misses. The general persona plus tools sits near the 4,096 floor; if reads report zero, pad the persona with the shared rules rather than shrink it.

## Cost sketch per turn

Prices from [platform.claude.com/docs/en/about-claude/pricing](https://platform.claude.com/docs/en/about-claude/pricing), Haiku 4.5: input $1 per MTok, 5 min cache write $1.25, 1 h write $2, cache read $0.10, output $5. Tool-use system prompt for Haiku 4.5 with `tool_choice: auto` is 496 tokens (same page).

Assumptions (measured or stated): planning persona 2,700 tokens (measured); 32 tool schemas 2,500 tokens (estimate, not measured); context block 1,500 (mp-019); 20 messages at 80 tokens each, 1,600 (estimate); reply 250 output tokens (estimate).

| Case | Input tokens and rate | Input cost | Output cost | Turn total |
|---|---|---|---|---|
| Today, no caching | 496 + 2,500 + 2,700 + 1,500 + 1,600 = 8,796 at $1 | $0.0088 | 250 at $5 = $0.00125 | $0.0101 |
| Caching on, context block still rebuilt every turn | 5,696 read at $0.10; 3,100 written at $1.25 | $0.00057 + $0.00388 = $0.0044 | $0.00125 | $0.0057 |
| Caching on, stable context, growing history (recommended) | 8,636 read at $0.10; 160 new tail written at $1.25 | $0.00086 + $0.00020 = $0.0011 | $0.00125 | $0.0023 |
| First turn after a gap over 5 minutes | 7,196 prefix written at $1.25; 1,600 history at $1.25 | $0.0110 | $0.00125 | $0.0122 once, then back to $0.0023 |

Read: the recommended shape cuts a mid-conversation turn from about one cent to about a quarter of a cent, and output becomes the largest line. A 40-turn planning session goes from roughly $0.40 to roughly $0.11 including one cold write. The compaction call at message 30 costs one extra Haiku call of about 2,000 input tokens, $0.002, per 20 turns.

## Sources

- Anthropic prompt caching: https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- Anthropic pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic context editing and compaction: https://platform.claude.com/docs/en/build-with-claude/context-editing
- Claude memory (help center): https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
- Claude memory (blog): https://claude.com/blog/memory
- OpenAI conversation state: https://developers.openai.com/api/docs/guides/conversation-state
- OpenAI compaction: https://developers.openai.com/api/docs/guides/compaction
- OpenAI prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- OpenAI ChatGPT memory (fetch blocked, read via search excerpt): https://openai.com/index/memory-and-new-controls-for-chatgpt/
- Vercel AI SDK message persistence (send only the last message, rebuild on the server): https://ai-sdk.dev/docs/ai-sdk-ui/chatbot-message-persistence
- Vercel AI SDK loop control, `prepareStep`, `pruneMessages`: https://ai-sdk.dev/docs/agents/loop-control
- Vercel AI SDK Anthropic provider cache control: https://ai-sdk.dev/providers/ai-sdk-providers/anthropic
- Vercel AI Gateway automatic caching: https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching
- LangChain short-term memory: https://docs.langchain.com/oss/python/langchain/short-term-memory
- LangChain long-term memory: https://docs.langchain.com/oss/python/langchain/long-term-memory
- LangChain SummarizationMiddleware source: https://raw.githubusercontent.com/langchain-ai/langchain/master/libs/langchain_v1/langchain/agents/middleware/summarization.py
- LlamaIndex memory: https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/memory/
- Character.AI memory: https://blog.character.ai/memory/
- Character.AI inference: https://blog.character.ai/optimizing-ai-inference-at-character-ai-2/
- Inflection Pi Journeys: https://inflection.ai/labs/pi-journeys
