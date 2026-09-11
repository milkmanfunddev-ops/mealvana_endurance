import {
  fulfillmentFilter,
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
// A `client_credentials` token, kept for as long as Kroger says it lives.
// Locations needs no scope and Products needs only `product.compact`, so one
// application token serves every catalog read the feature makes.
interface CachedToken {
  token: string;
  expires: number;
}
// Shared across warm invocations of the same isolate: the token endpoint has a
// daily limit like every other Kroger endpoint, and re-minting per request
// spends it for nothing. Tests pass their own cache instead.
const applicationTokens = new Map<string, CachedToken>();

export class KrogerClient {
  constructor(
    readonly config: Config,
    private fetcher: typeof fetch = fetch,
    private cache: Map<string, CachedToken> = applicationTokens,
  ) {}
  // A request that never got an answer (refused, reset, timed out) is
  // Kroger's failure, not this function's.
  private async request(url: string, init: RequestInit): Promise<Response> {
    try {
      return await this.fetcher(url, init);
    } catch {
      throw new KrogerError("kroger_unavailable", 502);
    }
  }
  // Kroger answered, but not with JSON: a maintenance page, say.
  private async json(response: Response): Promise<any> {
    try {
      return await response.json();
    } catch {
      throw new KrogerError("kroger_unavailable", 502);
    }
  }
  // Pays for Locations and Products. The shopper's own token pays for the
  // cart write and for nothing else, which is what lets Coverage be answered
  // before anyone has authorized Mealvana with Kroger.
  async applicationToken(): Promise<string> {
    const key = `${this.config.base}:${this.config.clientId}`;
    const cached = this.cache.get(key);
    if (cached && cached.expires > Date.now() + 60000) return cached.token;
    const body = await this.token({
      grant_type: "client_credentials",
      scope: "product.compact",
    }).catch((e) => {
      // A refused application credential is Mealvana's problem, not the
      // shopper's: they have nothing to reconnect.
      if (e instanceof KrogerError && e.code === "reconnect_required") {
        throw new KrogerError("not_configured", 503);
      }
      throw e;
    });
    this.cache.set(key, {
      token: body.access_token,
      expires: Date.now() + Number(body.expires_in) * 1000,
    });
    return body.access_token;
  }
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
    const body = await this.json(response);
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
    return await this.json(response);
  }
  async product(
    upc: string,
    store: string,
    mode: Modality,
    token: string,
  ): Promise<Product> {
    // Filtered by fulfillment like the search was: an item the Location cannot
    // serve this way is absent from the response, which is the answer.
    const params = new URLSearchParams({
      "filter.locationId": store,
      "filter.fulfillment": fulfillmentFilter(mode),
    });
    const raw = await this.get(
      `/products/${encodeURIComponent(upc)}?${params}`,
      token,
    );
    const product = productFromApi(raw.data);
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
