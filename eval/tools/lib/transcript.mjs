// The transcript renderer: vana_conversations / vana_messages rows exactly as
// supabase/functions/_shared/vana/chat.ts writes them, to markdown. Pure — the dev pull that
// fills these rows is capture-transcript.mjs's job.
//
// Row shapes (chat.ts: userMessageRow / assistantMessageRow):
//   user row:      content, parts, metadata.situation (the screen line that rode the turn)
//   assistant row: content (first text), parts (text parts + `tool-<name>` parts with
//                  input/output), metadata { tool_calls: string[], duration_ms, opener,
//                  opener_variant, new_plan, kind, plan_snapshot, opener_prompt, situation }
// Legacy assistant rows (before `parts` existed) carry only content.

const DEFAULT_MAX_PART_CHARS = 2000;

const json = (value, maxChars) => {
  const s = JSON.stringify(value, null, 2) ?? String(value);
  if (maxChars == null || s.length <= maxChars) return s;
  return `${s.slice(0, maxChars)}\n… [truncated, ${maxChars} of ${s.length} chars shown — run without --clip for everything]`;
};

const seconds = (ms) => `${(ms / 1000).toFixed(1)}s`;

/** Render one message row as markdown blocks, appended to `out`. */
function renderMessage(out, row, index, maxPartChars) {
  const who = row.role === 'user' ? 'Athlete' : row.role === 'assistant' ? 'Vana' : row.role;
  const meta = row.metadata ?? {};
  const tags = [];
  if (row.role === 'assistant') {
    if (meta.duration_ms != null) tags.push(seconds(meta.duration_ms));
    if (Array.isArray(meta.tool_calls) && meta.tool_calls.length) tags.push(`tools: ${meta.tool_calls.join(', ')}`);
    if (meta.opener) tags.push(`opener${meta.opener_variant ? ` (${meta.opener_variant})` : ''}`);
    if (meta.new_plan) tags.push('new plan');
  }
  out.push(`## ${index}. ${who} — ${row.created_at}${tags.length ? ` — ${tags.join(' · ')}` : ''}`, '');

  // The screen line rides on user rows (mp-420 clause 5) and on an opener's assistant row
  // (chat.ts stores the moment's line beside the opener_prompt).
  if (typeof meta.situation === 'string' && meta.situation) {
    out.push(`screen line: \`${meta.situation}\``, '');
  }

  const parts = Array.isArray(row.parts) && row.parts.length
    ? row.parts
    : (row.content ? [{ type: 'text', text: row.content }] : []);
  for (const part of parts) {
    if (part?.type === 'text' && part.text) {
      out.push(part.text, '');
    } else if (typeof part?.type === 'string' && part.type.startsWith('tool-')) {
      const name = part.type.slice('tool-'.length);
      out.push('```');
      out.push(`[tool ${name}]`);
      if (part.input && Object.keys(part.input).length) out.push(`input:\n${json(part.input, maxPartChars)}`);
      out.push(`output:\n${json(part.output, maxPartChars)}`);
      out.push('```', '');
    }
  }
  if (row.role === 'assistant' && typeof meta.opener_prompt === 'string' && meta.opener_prompt) {
    out.push('<details><summary>hidden opener prompt (stored on the row, replayed on the next turn)</summary>', '');
    out.push(meta.opener_prompt, '');
    out.push('</details>', '');
  }
}

/** The full transcript as markdown: header with conversation, account, and counts, then every
 *  message in order. `maxPartChars: null` disables tool-output truncation. */
export function renderTranscript({ conversation, account, userId, messages }, { maxPartChars = DEFAULT_MAX_PART_CHARS } = {}) {
  const rows = messages ?? [];
  const athletes = rows.filter((r) => r.role === 'user').length;
  const vana = rows.filter((r) => r.role === 'assistant').length;
  const out = [];
  out.push(`# Transcript: ${conversation.title || conversation.id}`, '');
  out.push(`- Conversation: ${conversation.id}`);
  out.push(`- Account: ${account}${userId ? ` (user ${userId})` : ''}`);
  out.push(`- Kind: ${conversation.kind}`);
  out.push(`- Created: ${conversation.created_at}`);
  out.push(`- Last message: ${conversation.last_message_at}`);
  out.push(`- Messages: ${rows.length} (${athletes} athlete, ${vana} Vana)`, '');
  out.push('---', '');
  rows.forEach((row, i) => renderMessage(out, row, i + 1, maxPartChars));
  return out.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd() + '\n';
}
