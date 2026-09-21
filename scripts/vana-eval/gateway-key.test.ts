/** `deno test scripts/vana-eval/gateway-key.test.ts` */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { evalsGatewayKey } from './gateway-key.ts';

const envOf = (o: Record<string, string>) => (k: string) => o[k];
const silent = () => {};

Deno.test('the exported evals key wins', () => {
  assertEquals(evalsGatewayKey({ env: envOf({ AI_GATEWAY_API_KEY_EVALS: 'e', AI_GATEWAY_API_KEY: 'd' }), file: { AI_GATEWAY_API_KEY_EVALS: 'f' } }), 'e');
});

Deno.test('the secrets file evals key comes next', () => {
  assertEquals(evalsGatewayKey({ env: envOf({ AI_GATEWAY_API_KEY: 'd' }), file: { AI_GATEWAY_API_KEY_EVALS: 'f' } }), 'f');
});

Deno.test('an exported plain key is the fallback, with a warning', () => {
  const warned: string[] = [];
  assertEquals(evalsGatewayKey({ env: envOf({ AI_GATEWAY_API_KEY: 'd' }), file: {}, warn: (m) => warned.push(m) }), 'd');
  assertEquals(warned.length, 1);
});

Deno.test("the file's plain key is never spent", () => {
  assertEquals(evalsGatewayKey({ env: envOf({}), file: { AI_GATEWAY_API_KEY: 'old' }, warn: silent }), null);
});
