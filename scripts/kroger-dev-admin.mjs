// Mealvana DEV target only. Kroger's API environment is a separate selection.
// No Mealvana production target or cart-write mode.
// node scripts/kroger-dev-admin.mjs inspect|apply|secrets|secrets-production|deploy|verify|enable|verify-enabled|verify-production
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { spawnSync } from "node:child_process";

const project = "vlmtsdzpnjnavdgytcmi";
const url = `https://${project}.supabase.co`;
function parse(raw) {
  return Object.fromEntries(
    raw.split(/\r?\n/).flatMap((line) => {
      const m = /^([A-Z_]+)=(.*)$/.exec(line);
      return m ? [[m[1], m[2].trim().replace(/^(['"])(.*)\1$/, "$2")]] : [];
    }),
  );
}
async function main() {
  const mode = process.argv[2];
  if (
    ![
      "inspect",
      "apply",
      "secrets",
      "secrets-production",
      "deploy",
      "verify",
      "enable",
      "verify-enabled",
      "verify-production",
    ].includes(mode)
  ) throw new Error("Unknown dev administration mode.");
  const clientEnv = parse(await readFile(".env.dev.local", "utf8"));
  if (clientEnv.SUPABASE_URL?.replace(/\/$/, "") !== url) {
    throw new Error("Dev project mismatch; stopped.");
  }
  let pat;
  try {
    pat = (await readFile(`${homedir()}/.supabase/pat`, "utf8")).trim();
  } catch (e) {
    if (e.code !== "ENOENT") throw e;
    pat = parse(await readFile("secrets/supabase_management_api.env", "utf8"))
      .SUPABASE_MANAGEMENT_TOKEN;
  }
  if (!pat) throw new Error("Supabase management credential unavailable.");
  async function management(path, method = "GET", body) {
    const response = await fetch(
      `https://api.supabase.com/v1/projects/${project}${path}`,
      {
        method,
        headers: {
          Authorization: `Bearer ${pat}`,
          "Content-Type": "application/json",
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!response.ok) {
      throw new Error(
        `Dev management request failed (HTTP ${response.status}); response withheld.`,
      );
    }
    const raw = await response.text();
    return raw ? JSON.parse(raw) : null;
  }
  const query = (sql) => management("/database/query", "POST", { query: sql });
  if (mode === "enable") {
    await management("/secrets", "POST", [{
      name: "KROGER_ENABLED",
      value: "true",
    }]);
    console.log("PASS: Kroger enabled on Mealvana DEV only; verify API environment separately.");
  }
  if (mode === "deploy") {
    const result = spawnSync("bash", ["scripts/deploy_dev.sh", "kroger"], {
      encoding: "utf8",
      env: { ...process.env, SUPABASE_ACCESS_TOKEN: pat },
    });
    // The wrapper prints project/function details only, never secret values.
    console.log(result.stdout);
    console.error(result.stderr);
    if (result.status !== 0) {
      throw new Error("Dev-only function deployment failed.");
    }
  }
  if (mode === "inspect" || mode === "verify") {
    const schema = await query(
      "select table_name, column_name, data_type from information_schema.columns where table_schema='public' and (table_name like 'kroger_%' or table_name='meal_plans' and column_name in ('id','user_id','is_deleted')) order by table_name, ordinal_position",
    );
    console.log(JSON.stringify({ target: "dev", schema }, null, 2));
    const functions = await management("/functions");
    console.log(
      JSON.stringify({
        kroger: functions.filter((f) => f.slug === "kroger").map((f) => ({
          slug: f.slug,
          status: f.status,
          version: f.version,
          verify_jwt: f.verify_jwt,
          updated_at: f.updated_at,
        })),
      }),
    );
    const grants = await query(
      "select c.relname, c.relrowsecurity as rls, has_table_privilege('authenticated',c.oid,'SELECT') as client_select, has_table_privilege('authenticated',c.oid,'INSERT') as client_insert from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname like 'kroger_%' and c.relkind='r' order by c.relname",
    );
    console.log(JSON.stringify({ grants }));
  }
  if (mode === "apply") {
    const sql = await readFile(
      "supabase/migrations/20260907120000_kroger_shopping.sql",
      "utf8",
    );
    await query(
      `begin; select pg_advisory_xact_lock(hashtext('kroger-shopping-migration')); ${sql}\ncommit;`,
    );
    console.log(
      "PASS: Kroger-only migration applied to dev in one transaction.",
    );
  }
  if (mode === "secrets" || mode === "secrets-production") {
    const productionApi = mode === "secrets-production";
    const env = parse(await readFile(
      productionApi ? "secrets/kroger.prod.env" : "secrets/kroger.env", "utf8",
    ));
    if (
      !env.KROGER_CLIENT_ID || !env.KROGER_CLIENT_SECRET ||
      env.KROGER_USE_CERTIFICATION !== (productionApi ? "false" : "true")
    ) throw new Error("Credentials must match the explicitly selected Kroger environment.");
    if (productionApi) {
      if (env.KROGER_CLIENT_ID !== "mealvanaenduranceprod-bbchhzz3" ||
          env.KROGER_REDIRECT_URI !== "com.milkman.mealvanaendurance://callback") {
        throw new Error("Production registration mismatch; stopped before uploading.");
      }
      // Validate application credentials only; never request customer or cart access.
      const probe = await fetch("https://api.kroger.com/v1/connect/oauth2/token", {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(`${env.KROGER_CLIENT_ID}:${env.KROGER_CLIENT_SECRET}`).toString("base64")}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ grant_type: "client_credentials", scope: "product.compact" }),
        signal: AbortSignal.timeout(30000),
      });
      if (!probe.ok) throw new Error(`Kroger Production credential check failed (HTTP ${probe.status}); no configuration uploaded.`);
      const token = await probe.json();
      if (!token.access_token || !(Number(token.expires_in) > 0)) {
        throw new Error("Invalid Production token response; no configuration uploaded.");
      }
      console.log("PASS: Kroger Production accepts the new application credentials; token withheld.");
    }
    const values = {
      KROGER_CLIENT_ID: env.KROGER_CLIENT_ID,
      KROGER_CLIENT_SECRET: env.KROGER_CLIENT_SECRET,
      KROGER_USE_CERTIFICATION: productionApi ? "false" : "true",
      KROGER_REDIRECT_URI: env.KROGER_REDIRECT_URI,
      KROGER_ENABLED: "false",
    };
    if (!values.KROGER_REDIRECT_URI) {
      throw new Error("Registered redirect required.");
    }
    await management(
      "/secrets",
      "POST",
      Object.entries(values).map(([name, value]) => ({ name, value })),
    );
    console.log(
      "PASS: five Kroger-only secrets uploaded to dev; KROGER_ENABLED=false. Values withheld.",
    );
  }
  if (mode === "verify" || mode === "verify-enabled" || mode === "verify-production") {
    const endpoint = `${url}/functions/v1/kroger`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "status" }),
      signal: AbortSignal.timeout(30000),
    });
    if (response.status !== 401) {
      throw new Error(
        `Expected unauthenticated 401; received ${response.status}.`,
      );
    }
    console.log("PASS: unauthenticated requests rejected (401).");
    // Dedicated dev-login Keychain entry documented by scripts/sim-dev-login.sh.
    // Password and session tokens stay in memory; never in arguments or output.
    const metadata = spawnSync("security", [
      "find-generic-password",
      "-s",
      "mealvana-dev-login",
    ], { encoding: "utf8" });
    const email = /"acct"<blob>="([^"]+)"/.exec(metadata.stdout)?.[1];
    const passwordResult = spawnSync("security", [
      "find-generic-password",
      "-s",
      "mealvana-dev-login",
      "-w",
    ], { encoding: "utf8" });
    const key = clientEnv.SUPABASE_PUBLISHABLE_KEY ||
      clientEnv.SUPABASE_ANON_KEY;
    if (!email || passwordResult.status !== 0 || !key) {
      throw new Error(
        "Dedicated dev login unavailable; signed-in smoke test not performed.",
      );
    }
    const auth = await fetch(`${url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        password: passwordResult.stdout.trimEnd(),
      }),
      signal: AbortSignal.timeout(30000),
    });
    if (!auth.ok) {
      throw new Error(
        `Dev login failed (HTTP ${auth.status}); response withheld.`,
      );
    }
    const session = await auth.json();
    const signed = await fetch(endpoint, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${session.access_token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ action: "status" }),
      signal: AbortSignal.timeout(30000),
    });
    if (!signed.ok) {
      throw new Error(
        `Signed-in status failed (HTTP ${signed.status}); response withheld.`,
      );
    }
    const body = await signed.json();
    const expected = mode !== "verify";
    if (body.available !== expected) {
      throw new Error(`Expected available=${expected}.`);
    }
    const expectedEnvironment = mode === "verify-production" ? "production" : "certification";
    if (expected && body.environment !== expectedEnvironment) {
      throw new Error(`Expected ${expectedEnvironment} environment; received ${body.environment}.`);
    }
    console.log(
      `PASS: authenticated status returns available=${expected}, environment=${body.environment ?? "disabled"}. No customer OAuth/cart requests made.`,
    );
  }
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
