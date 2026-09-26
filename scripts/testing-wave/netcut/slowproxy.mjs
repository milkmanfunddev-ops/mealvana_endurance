#!/usr/bin/env node
// The host side of `netcut.sh slow` (IMPROVEMENTS #92): a byte pipe on loopback that answers late.
// netcut.dylib sends the app's TCP connects here while <dir>/slow.flag exists and appends
// "<source port> <host> <port>" to <dir>/slow.map first; this proxy looks the socket up by its
// source port, connects to the real server and pipes both ways. Every chunk coming back from the
// server is held for the delay in slow.flag ("<ms> <port>", re-read each chunk, so `slow 500`
// after `slow 3000` applies to open connections too), in order. TLS passes through untouched.
//
//   node slowproxy.mjs <dir>     listens on a free port (127.0.0.1 and ::1), writes it to
//                                <dir>/slowproxy.port, logs connections to <dir>/slowproxy.log.
// slow.flag may name hosts after the port ("<ms> <port> api.revenuecat.com"): then only replies
// from those hosts' addresses are held.
// Exits by itself once slow.flag is gone and no connection has been open for 30 s.
import net from 'node:net';
import { readFileSync, writeFileSync, appendFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { lookup } from 'node:dns/promises';

const dir = process.argv[2];
if (!dir) { process.stderr.write('usage: slowproxy.mjs <dir>\n'); process.exit(64); }
const flag = join(dir, 'slow.flag');
const mapFile = join(dir, 'slow.map');
const log = line => appendFileSync(join(dir, 'slowproxy.log'), `${new Date().toISOString()} ${line}\n`);

// slow.flag: "<ms> <port> [host ...]". With hosts, only connections to their addresses are held;
// the rest pass at once (to slow one service, such as RevenueCat, and nothing else).
const readFlag = () => { try { return readFileSync(flag, 'utf8').trim().split(/\s+/); } catch { return null; } };
const resolved = new Map(); // host -> Set of addresses, looked up once
async function addressesOf(host) {
  if (!resolved.has(host)) {
    resolved.set(host, new Set());
    try { for (const a of await lookup(host, { all: true })) resolved.get(host).add(a.address); } catch { /* unknown host: matches nothing */ }
  }
  return resolved.get(host);
}
async function refreshHosts() { for (const h of (readFlag() ?? []).slice(2)) await addressesOf(h); }
export const delayMs = dstHost => {
  const f = readFlag();
  if (!f) return 0;
  const ms = Number(f[0]);
  if (!Number.isFinite(ms) || ms <= 0) return 0;
  const hosts = f.slice(2);
  if (hosts.length === 0) return ms;
  return hosts.some(h => resolved.get(h)?.has(dstHost)) ? ms : 0;
};

/** The real destination of a socket from source port [port]: the newest map line for it. */
function destination(port) {
  let text = '';
  try { text = readFileSync(mapFile, 'utf8'); } catch { return null; }
  const lines = text.trimEnd().split('\n');
  for (let i = lines.length - 1; i >= 0; i--) {
    const [src, host, dst] = lines[i].split(' ');
    if (Number(src) === port) return { host, port: Number(dst) };
  }
  return null;
}

let open = 0;
let idleSince = Date.now();

function handle(client) {
  open++;
  const started = Date.now();
  const src = client.remotePort;
  let tries = 0;
  const find = async () => {
    await refreshHosts();
    const dst = destination(src);
    if (dst) return connect(dst);
    if (++tries > 50) { log(`no map line for source port ${src}; closed`); client.destroy(); return; }
    setTimeout(find, 10); // the map line is written before the connect, so this is rare
  };
  const connect = dst => {
    const upstream = net.connect({ host: dst.host, port: dst.port });
    let lastAt = 0;
    let down = 0;
    let first = null;
    client.on('data', chunk => upstream.write(chunk));
    upstream.on('data', chunk => {
      // Each chunk leaves no sooner than the delay after it came, and never before an earlier one.
      const at = Math.max(Date.now() + delayMs(dst.host), lastAt);
      lastAt = at;
      upstream.pause();
      setTimeout(() => {
        if (first === null) first = Date.now() - started;
        down += chunk.length;
        if (!client.destroyed) client.write(chunk);
        upstream.resume();
      }, at - Date.now());
    });
    client.on('end', () => upstream.end());
    upstream.on('end', () => setTimeout(() => client.end(), Math.max(0, lastAt - Date.now())));
    const done = why => () => {
      if (client.done) return;
      client.done = true;
      open--; if (open === 0) idleSince = Date.now();
      log(`${dst.host}:${dst.port} from :${src} ${why}: ${down} bytes back, first after ${first ?? '-'} ms, open ${Date.now() - started} ms`);
      client.destroy(); upstream.destroy();
    };
    upstream.on('error', e => done(`upstream error ${e.code ?? e.message}`)());
    client.on('error', e => done(`client error ${e.code ?? e.message}`)());
    upstream.on('close', () => setTimeout(done('closed'), Math.max(0, lastAt - Date.now()) + 10));
    client.on('close', done('closed'));
    log(`${dst.host}:${dst.port} from :${src} open (delay ${delayMs(dst.host)} ms)`);
  };
  find();
}

const v4 = net.createServer(handle);
v4.listen(0, '127.0.0.1', () => {
  const { port } = v4.address();
  const v6 = net.createServer(handle);
  v6.on('error', e => log(`::1 not served (${e.code}); IPv6 connects stay direct`));
  v6.listen(port, '::1');
  writeFileSync(join(dir, 'slowproxy.port'), String(port));
  log(`listening on :${port}`);
});

setInterval(() => {
  if (!existsSync(flag) && open === 0 && Date.now() - idleSince > 30_000) { log('slow.flag gone and idle; exiting'); process.exit(0); }
}, 5_000);
