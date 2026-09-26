#!/usr/bin/env node
// Transcript capture for a judged Run (vana-judging ticket 05). Round protocol step 4: after a
// Run, the Mark is based on the exact conversation the server persisted — vana_conversations /
// vana_messages, both sides of every turn, tool calls in `parts`, metadata (duration, opener,
// hidden opener prompt, screen line) — never on the Examiner's memory of the session. The
// onTrace hook is not the capture path; these tables are.
//
// Read-only against DEV through the Management API (token from $SUPABASE_ACCESS_TOKEN /
// $SUPABASE_PAT, else the main clone's secrets file). PROD is refused.
//
//   node eval/tools/capture-transcript.mjs --account test@test.com
//       lists the account's conversations (id, kind, title, last message, turn count) and exits
//   node eval/tools/capture-transcript.mjs --account test@test.com --conversation <uuid> \
//          --round 001 --scenario <slug>
//       writes eval/runs/001/<slug>.transcript.md   (the round layout in eval/README.md)
//   … --out <path>    write anywhere else instead (e.g. a scratch dir outside /eval when
//                     verifying plumbing against a private account's conversation)
//   … --full          no tool-output truncation (default: each input/output clipped at 2000
//                     chars with a marker; a picker's 24-meal tail is otherwise unreadable)
//
// Exit 2: usage. Exit 1: nothing found / query failed.

import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertUuid, query, sqlString } from './lib/devdb.mjs';
import { renderTranscript } from './lib/transcript.mjs';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const EMAIL = /^[^\s'";]+@[^\s'";]+$/;

function usage(message) {
  if (message) console.error(`capture-transcript: ${message}`);
  console.error('usage: capture-transcript.mjs --account <email> [--conversation <uuid>] [--round <NNN> --scenario <slug> | --out <path>] [--full] [--ref dev]');
  process.exit(message ? 2 : 0);
}

const args = { full: false };
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  const value = () => {
    const v = process.argv[++i];
    if (v === undefined || v.startsWith('--')) usage(`${a} needs a value`);
    return v;
  };
  if (a === '--account') args.account = value();
  else if (a === '--conversation') args.conversation = value();
  else if (a === '--round') args.round = value();
  else if (a === '--scenario') args.scenario = value();
  else if (a === '--out') args.out = value();
  else if (a === '--ref') args.ref = value();
  else if (a === '--full') args.full = true;
  else if (a === '--help' || a === '-h') usage();
  else usage(`unknown flag ${a}`);
}
if (!args.account || !EMAIL.test(args.account)) usage('--account <email> is required');
if ((args.round || args.scenario) && !(args.round && args.scenario)) usage('--round and --scenario go together');
if (args.conversation && !args.out && !(args.round && args.scenario)) usage('give either --out <path> or --round <NNN> --scenario <slug>');
if (args.conversation) assertUuid(args.conversation, '--conversation');

const email = sqlString(args.account.toLowerCase());

const users = await query(`select id, email from auth.users where lower(email) = ${email} limit 2`);
if (users.length === 0) {
  console.error(`capture-transcript: no auth user for ${args.account} on dev`);
  process.exit(1);
}
if (users.length > 1) {
  console.error(`capture-transcript: ${args.account} matches ${users.length} auth users on dev; disambiguate before capturing`);
  process.exit(1);
}
const { id: userId, email: actualEmail } = users[0];
const uid = sqlString(userId);

const conversations = await query(`
  select c.id, c.kind, c.title, c.created_at, c.last_message_at,
         (select count(*)::int from vana_messages m where m.conversation_id = c.id) as messages
  from vana_conversations c
  where c.user_id = ${uid} and c.is_deleted = false
  order by c.last_message_at desc nulls last
  limit 20`);

if (!args.conversation) {
  if (conversations.length === 0) {
    console.error(`capture-transcript: ${actualEmail} has no conversations on dev`);
    process.exit(1);
  }
  console.log(`conversations for ${actualEmail} (pass --conversation <id>):`);
  for (const c of conversations) {
    console.log(`  ${c.id}  ${String(c.kind).padEnd(14)} ${String(c.messages).padStart(3)} msgs  ${c.last_message_at ?? ''}  ${c.title ?? ''}`);
  }
  process.exit(0);
}

const [conversation] = conversations.filter((c) => c.id === args.conversation);
if (!conversation) {
  console.error(`capture-transcript: conversation ${args.conversation} is not one of ${actualEmail}'s live conversations on dev`);
  process.exit(1);
}

const messages = await query(`
  select id, role, content, parts, metadata, created_at
  from vana_messages
  where conversation_id = ${sqlString(args.conversation)} and user_id = ${uid}
  order by created_at asc`);
if (messages.length === 0) {
  console.error(`capture-transcript: conversation ${args.conversation} has no messages`);
  process.exit(1);
}

const markdown = renderTranscript(
  { conversation, account: actualEmail, userId, messages },
  { maxPartChars: args.full ? null : undefined },
);

const outPath = args.out
  ? resolve(args.out)
  : resolve(REPO_ROOT, 'eval', 'runs', args.round, `${args.scenario}.transcript.md`);
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, markdown);
console.log(`wrote ${messages.length} messages to ${outPath}`);
