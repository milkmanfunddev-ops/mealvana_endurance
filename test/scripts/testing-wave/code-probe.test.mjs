// node --test test/scripts/testing-wave/*.test.mjs
//
// The code probe: the host-side endpoint a Patrol flow calls for an email code on a lee+e2e-*
// account, so a flow can get past the verify screen without a mailbox.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readCode, startProbe } from '../../../scripts/testing-wave/code-probe.mjs';

const E2E = 'lee+e2e-1758628800000@rightpathprogramming.com';

const fakeAdmin = (reply = { email_otp: '123456' }) => {
  const calls = [];
  return {
    calls,
    authAdmin: async (path, init) => { calls.push({ path, body: JSON.parse(init.body) }); return reply; },
  };
};

test('a signup code for a lee+e2e account comes from generate_link with the password', async () => {
  const admin = fakeAdmin();
  assert.deepEqual(await readCode(admin, { email: E2E, type: 'signup', password: 'pw-123456' }), { code: '123456' });
  assert.deepEqual(admin.calls, [{ path: '/generate_link', body: { type: 'signup', email: E2E, password: 'pw-123456' } }]);
});

test('magiclink and recovery codes need no password', async () => {
  for (const type of ['magiclink', 'recovery']) {
    const admin = fakeAdmin({ properties: { email_otp: '654321' } });
    assert.deepEqual(await readCode(admin, { email: E2E, type }), { code: '654321' });
    assert.deepEqual(admin.calls[0].body, { type, email: E2E });
  }
});

test('any address that is not lee+e2e-* is refused before the admin API is called', async () => {
  for (const email of ['test@test.com', 'lee@rightpathprogramming.com', 'lee+e2e-1@gmail.com']) {
    const admin = fakeAdmin();
    await assert.rejects(readCode(admin, { email, type: 'magiclink' }), /lee\+e2e/);
    assert.equal(admin.calls.length, 0);
  }
});

test('an unknown type, or a signup without a password, is refused', async () => {
  await assert.rejects(readCode(fakeAdmin(), { email: E2E, type: 'invite' }), /type/);
  await assert.rejects(readCode(fakeAdmin(), { email: E2E, type: 'signup' }), /password/);
});

test('no code in the reply is an error, never an empty code', async () => {
  await assert.rejects(readCode(fakeAdmin({ action_link: 'x' }), { email: E2E, type: 'magiclink' }), /no code/);
});

test('the server answers POST /code with the code and 400 on a refusal, on loopback only', async () => {
  const server = await startProbe({ admin: fakeAdmin(), port: 0 });
  const { address, port } = server.address();
  assert.equal(address, '127.0.0.1');
  const post = body => fetch(`http://127.0.0.1:${port}/code`, { method: 'POST', body: JSON.stringify(body) });
  try {
    const ok = await post({ email: E2E, type: 'magiclink' });
    assert.equal(ok.status, 200);
    assert.deepEqual(await ok.json(), { code: '123456' });
    const bad = await post({ email: 'test@test.com', type: 'magiclink' });
    assert.equal(bad.status, 400);
    assert.match((await bad.json()).error, /lee\+e2e/);
    assert.equal((await fetch(`http://127.0.0.1:${port}/other`)).status, 404);
  } finally {
    server.close();
  }
});
