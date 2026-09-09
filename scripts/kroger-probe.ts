// Read-only certification smoke test. Never calls customer/profile/cart endpoints.
// deno run --allow-read=secrets/kroger.env --allow-net=api-ce.kroger.com scripts/kroger-probe.ts
import { KrogerClient } from "../supabase/functions/_shared/kroger/client.ts";
import {
  KrogerError,
  productFromApi,
} from "../supabase/functions/_shared/kroger/catalog.ts";

async function main() {
  const values: Record<string, string> = {};
  const raw = await Deno.readTextFile("secrets/kroger.env");
  for (const line of raw.split(/\r?\n/)) {
    const match = /^([A-Z_]+)=(.*)$/.exec(line);
    if (match) {
      values[match[1]] = match[2].trim().replace(/^(['"])(.*)\1$/, "$2");
    }
  }
  if (
    !values.KROGER_CLIENT_ID || !values.KROGER_CLIENT_SECRET ||
    values.KROGER_USE_CERTIFICATION === "false"
  ) {
    throw new Error(
      "Certification credentials are required in secrets/kroger.env.",
    );
  }
  const client = new KrogerClient({
    base: "https://api-ce.kroger.com/v1",
    environment: "certification",
    clientId: values.KROGER_CLIENT_ID,
    secret: values.KROGER_CLIENT_SECRET,
    redirect: values.KROGER_REDIRECT_URI,
  });
  const token = await client.token({
    grant_type: "client_credentials",
    scope: "product.compact",
  });
  console.log("PASS: certification client-credentials authentication");
  const locations = await client.get(
    "/locations?filter.zipCode.near=45202&filter.limit=1",
    token.access_token,
  );
  console.log(
    `PASS: locations endpoint (${locations.data?.length ?? 0} returned)`,
  );
  const store = locations.data?.[0]?.locationId;
  if (!store) {
    throw new Error(
      "No certification store returned; catalog search not verified.",
    );
  }
  const products = await client.get(
    `/products?filter.term=milk&filter.locationId=${
      encodeURIComponent(store)
    }&filter.limit=2`,
    token.access_token,
  );
  console.log(
    `PASS: store-specific product search (${
      products.data?.length ?? 0
    } returned)`,
  );
  const normalized = (products.data ?? []).map((p: unknown) =>
    productFromApi(p, "PICKUP")
  ).filter(Boolean);
  if (!normalized.length) throw new KrogerError("catalog_normalization_failed");
  const detail = await client.product(
    normalized[0].upc,
    store,
    "PICKUP",
    token.access_token,
  );
  console.log(
    `PASS: UPC detail lookup and normalization (pickup eligible: ${detail.available}; size supplied: ${!!detail
      .size}; price supplied: ${detail.price != null})`,
  );
  console.log("No customer authorization or cart mutation performed.");
  if (!detail.available) {
    console.log(
      "NOTE: sampled fixture is not pickup-eligible; customer/cart acceptance still needs an eligible certification fixture.",
    );
  }
}
try {
  await main();
} catch (error) {
  // Sanitized errors only: never log fetch requests/responses or credentials.
  console.error(
    "FAIL:",
    error instanceof KrogerError
      ? error.code
      : "Certification probe failed; inspect configuration/network without logging secrets.",
  );
  Deno.exitCode = 1;
}
