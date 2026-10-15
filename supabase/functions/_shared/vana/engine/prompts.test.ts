/** The v7 prompt files load by stem through workspace.env; scripted.md parses into the lines code sends. */
import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { filePromptSource, v7PromptsDir, memoryPrompts } from './prompts.ts';
import { loadScripted, DEFAULT_LINES } from './scripted.ts';
import { readSystem } from './read.ts';

const dir = v7PromptsDir();
const have = (() => { try { return !!dir && Deno.statSync(dir).isDirectory; } catch { return false; } })();

Deno.test({ name: 'every stem the engine loads exists in ops/experiments/setup-chat/v7/prompts', ignore: !have, fn: async () => {
  const p = filePromptSource(dir!);
  for (const stem of ['shared', 'read', 'scripted', 'sensitive', 'shape-answer', 'shape-choose', 'shape-draft-record', 'shape-hand-off', 'step-plan', 'step-wearable', 'step-formula', 'step-long-run', 'step-race']) {
    const t = await p.get(stem);
    assertStringIncludes(t, '# ');
  }
  const r = readSystem(await p.get('read'), 'Your plan lands here.', 'plan');
  assertStringIncludes(r, "Vana's last line: Your plan lands here.");
  assertStringIncludes(r, 'The step Vana is on: plan');
} });

Deno.test({ name: 'scripted.md yields the off-flow, wrap, receipt and sensitive lines', ignore: !have, fn: async () => {
  const lines = await loadScripted(filePromptSource(dir!));
  assertEquals(lines.off_flow, "That's coming soon. I can't help with it yet.");
  assertEquals(lines.wrap, "That's your setup. There's more to explore in your formula library; tap through whenever.");
  assertEquals(lines.receipt, '{what}, {when}.');
  assertEquals(lines.receipt_race, 'It lives on your Events page.');
  assertEquals(lines.sensitive_medical, 'Would you like us to help you find a sports dietitian?');
  assertEquals(lines.sensitive_ed_close, 'We can pick setup up another time.');
} });

Deno.test('without scripted.md the defaults stand', async () => {
  assertEquals(await loadScripted(memoryPrompts({})), DEFAULT_LINES);
});
