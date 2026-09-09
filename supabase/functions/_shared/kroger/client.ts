import {
  KrogerError,
  type Modality,
  type Product,
  productFromApi,
} from "./catalog.ts";

export interface Config {
  base: string;
  clientId: string;
  secret: string;
  redirect: string;
  environment: string;
}
export function config(): Config {
  const environment = Deno.env.get("KROGER_USE_CERTIFICATION") === "false"
    ? "production"
    : "certification";
  const base = environment === "production"
    ? "https://api.kroger.com/v1"
    : "https://api-ce.kroger.com/v1";
  const clientId = Deno.env.get("KROGER_CLIENT_ID") ?? "";
  const secret = Deno.env.get("KROGER_CLIENT_SECRET") ?? "";
  if (!clientId || !secret || Deno.env.get("KROGER_ENABLED") !== "true") {
    throw new KrogerError("not_configured", 503);
  }
  return {
    base,
    clientId,
    secret,
    environment,
    redirect: Deno.env.get("KROGER_REDIRECT_URI") ??
      "com.milkman.mealvanaendurance://callback",
  };
}
export class KrogerClient {
  constructor(readonly config: Config, private request: typeof fetch = fetch) {}
  async token(fields: Record<string, string>): Promise<any> {
    const response = await this.request(
      `${this.config.base}/connect/oauth2/token`,
      {
        method: "POST",
        signal: AbortSignal.timeout(15000),
        headers: {
          Authorization: `Basic ${
            btoa(`${this.config.clientId}:${this.config.secret}`)
          }`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams(fields),
      },
    );
    if (!response.ok) {
      throw new KrogerError(
        response.status === 400 || response.status === 401
          ? "reconnect_required"
          : "kroger_unavailable",
        502,
      );
    }
    const body = await response.json();
    if (!body.access_token || !(Number(body.expires_in) > 0)) {
      throw new KrogerError("invalid_token_response", 502);
    }
    return body;
  }
  async get(path: string, token: string): Promise<any> {
    const response = await this.request(`${this.config.base}${path}`, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      throw new KrogerError(
        response.status === 401
          ? "reconnect_required"
          : response.status === 429
          ? "rate_limited"
          : "kroger_unavailable",
        502,
      );
    }
    return await response.json();
  }
  async product(
    upc: string,
    store: string,
    mode: Modality,
    token: string,
  ): Promise<Product> {
    const raw = await this.get(
      `/products/${encodeURIComponent(upc)}?filter.locationId=${
        encodeURIComponent(store)
      }`,
      token,
    );
    const product = productFromApi(raw.data, mode);
    if (!product || product.upc !== upc) {
      throw new KrogerError("product_unavailable");
    }
    return product;
  }
  // Never retry: a timeout or error can occur after Kroger has applied the add.
  async add(lines: unknown[], token: string): Promise<void> {
    const response = await this.request(`${this.config.base}/cart/add`, {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ items: lines }),
      signal: AbortSignal.timeout(20000),
    });
    if (response.status !== 204) throw new KrogerError("export_unknown", 502);
  }
}
