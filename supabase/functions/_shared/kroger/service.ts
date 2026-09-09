import type { Db } from "../vana/env.ts";
import { KrogerClient } from "./client.ts";
import {
  cartLines,
  fingerprint,
  fulfillmentFilter,
  KrogerError,
  modality,
  type Product,
  productFromApi,
  rankProducts,
  textInput,
} from "./catalog.ts";

const uuid = (v: unknown) => {
  const s = textInput(v, 36);
  if (!/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(s)) {
    throw new KrogerError("invalid_id");
  }
  return s;
};
// All Kroger will say about a product its filter no longer returns: the UPC
// asked for, and that it cannot be had. The ingredient's own name is on the
// shopper's line, not here.
const unavailableProduct = (upc: string): Product => ({
  upc,
  name: "",
  brand: "",
  size: "",
  price: null,
  available: false,
  image: null,
});
const checked = (result: any) => {
  if (result.error) throw new KrogerError("storage_unavailable", 503);
  return result.data;
};

export class KrogerService {
  constructor(
    private admin: Db,
    private userId: string,
    private client: KrogerClient,
  ) {}
  async customerToken(): Promise<string> {
    const row = checked(
      await this.admin.from("kroger_connections").select("*").eq(
        "user_id",
        this.userId,
      ).maybeSingle(),
    );
    if (!row || row.environment !== this.client.config.environment) {
      throw new KrogerError("reconnect_required", 409);
    }
    if (Date.parse(row.expires_at) > Date.now() + 120000) {
      return row.access_token;
    }
    if (!row.refresh_token) throw new KrogerError("reconnect_required", 409);
    const lease = new Date(Date.now() + 30000).toISOString();
    const claimed = checked(
      await this.admin.from("kroger_connections").update({
        refresh_locked_until: lease,
      }).eq("user_id", this.userId)
        .eq("access_token", row.access_token).eq(
          "environment",
          this.client.config.environment,
        )
        .lt("refresh_locked_until", new Date().toISOString()).select("user_id"),
    );
    if (!claimed.length) throw new KrogerError("connection_busy", 409);
    try {
      const token = await this.client.token({
        grant_type: "refresh_token",
        refresh_token: row.refresh_token,
      });
      const saved = checked(
        await this.admin.from("kroger_connections").update({
          access_token: token.access_token,
          refresh_token: token.refresh_token ?? row.refresh_token,
          expires_at: new Date(Date.now() + Number(token.expires_in) * 1000)
            .toISOString(),
          refresh_locked_until: new Date(0).toISOString(),
          updated_at: new Date().toISOString(),
        }).eq("user_id", this.userId).eq("refresh_locked_until", lease).select(
          "user_id",
        ),
      );
      if (saved.length !== 1) throw new KrogerError("reconnect_required", 409);
      return token.access_token;
    } catch (e) {
      // Keep the lease until expiry after an ambiguous refresh; no immediate concurrent replay.
      throw e;
    }
  }
  async run(action: string, body: any): Promise<Record<string, unknown>> {
    const { base, clientId, redirect, environment } = this.client.config;
    if (action === "status") {
      const connection = checked(
        await this.admin.from("kroger_connections").select("environment").eq(
          "user_id",
          this.userId,
        ).maybeSingle(),
      );
      return {
        available: true,
        connected: connection?.environment === environment,
        environment,
      };
    }
    if (action === "connect") {
      checked(
        await this.admin.from("kroger_oauth_sessions").delete().eq(
          "user_id",
          this.userId,
        ),
      );
      const state = crypto.randomUUID();
      checked(
        await this.admin.from("kroger_oauth_sessions").insert({
          state,
          user_id: this.userId,
          environment,
        }),
      );
      const url = new URL(`${base}/connect/oauth2/authorize`);
      url.search = new URLSearchParams({
        client_id: clientId,
        redirect_uri: redirect,
        response_type: "code",
        scope: "cart.basic:write profile.compact product.compact",
        state,
      }).toString();
      return { url: url.toString(), state, redirect };
    }
    if (action === "exchange") {
      const state = uuid(body.state), code = textInput(body.code, 4096);
      const rows = checked(
        await this.admin.from("kroger_oauth_sessions").delete().eq(
          "state",
          state,
        ).eq("user_id", this.userId)
          .eq("environment", environment).gt(
            "expires_at",
            new Date().toISOString(),
          ).select("state"),
      );
      if (rows.length !== 1) throw new KrogerError("invalid_oauth_state");
      const token = await this.client.token({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirect,
      });
      checked(
        await this.admin.from("kroger_connections").upsert({
          user_id: this.userId,
          access_token: token.access_token,
          refresh_token: token.refresh_token ?? null,
          expires_at: new Date(Date.now() + Number(token.expires_in) * 1000)
            .toISOString(),
          environment,
          refresh_locked_until: new Date(0).toISOString(),
          updated_at: new Date().toISOString(),
        }, { onConflict: "user_id" }),
      ); // full primary key, not a partial index
      return { connected: true };
    }
    if (action === "disconnect") {
      checked(
        await this.admin.from("kroger_connections").delete().eq(
          "user_id",
          this.userId,
        ),
      );
      checked(
        await this.admin.from("kroger_oauth_sessions").delete().eq(
          "user_id",
          this.userId,
        ),
      );
      return { connected: false };
    }
    // Catalog reads use the customer's token, keeping access scoped to connected customers.
    if (action === "stores") {
      // A zip when the athlete typed one; otherwise where they live. Home location is a Fact on
      // the user record (the Voodoo Doll spec, ticket 07), so shopping keys off their own town
      // rather than whatever venue their next race is at.
      // A zip the athlete typed must be a real one — a typo is an error, never a
      // silent search somewhere else. Only an ABSENT zip falls back to home.
      const rawZip = typeof body.zip === "string" ? body.zip.trim() : "";
      let filter: string;
      if (rawZip) {
        if (!/^\d{5}$/.test(rawZip)) throw new KrogerError("invalid_zip");
        filter = `filter.zipCode.near=${rawZip}`;
      } else {
        const { data: u } = await this.admin.from("users").select(
          "home_lat, home_lon",
        ).eq("id", this.userId).maybeSingle();
        if (u?.home_lat == null || u?.home_lon == null) {
          throw new KrogerError("invalid_zip");
        }
        filter = `filter.latLong.near=${Number(u.home_lat)},${
          Number(u.home_lon)
        }`;
      }
      const raw = await this.client.get(
        `/locations?${filter}&filter.limit=10`,
        await this.customerToken(),
      );
      return {
        stores: (raw.data ?? []).map((s: any) => ({
          id: s.locationId,
          name: s.name,
          address: [s.address?.addressLine1, s.address?.city, s.address?.state]
            .filter(Boolean).join(", "),
        })),
      };
    }
    if (action === "search") {
      const query = textInput(body.query),
        store = textInput(body.store, 30),
        mode = modality(body.modality);
      const params = new URLSearchParams({
        "filter.term": query,
        "filter.locationId": store,
        "filter.fulfillment": fulfillmentFilter(mode),
        "filter.limit": "15",
      });
      const raw = await this.client.get(
        `/products?${params}`,
        await this.customerToken(),
      );
      const products = (raw.data ?? []).map((p: any) => productFromApi(p))
        .filter(Boolean);
      return { products: rankProducts(query, products) };
    }
    if (action === "export_status") {
      const row = checked(
        await this.admin.from("kroger_exports").select("id,status,created_at")
          .eq("user_id", this.userId).eq("environment", environment).eq(
            "plan_id",
            uuid(body.planId),
          ).maybeSingle(),
      );
      return { receipt: row };
    }
    if (action === "export") return await this.export(body);
    throw new KrogerError("invalid_action");
  }
  private async export(body: any): Promise<Record<string, unknown>> {
    const planId = uuid(body.planId),
      id = uuid(body.id),
      store = textInput(body.store, 30),
      mode = modality(body.modality);
    const lines = cartLines(body.items, mode);
    const plan = checked(
      await this.admin.from("meal_plans").select("id").eq("id", planId).eq(
        "user_id",
        this.userId,
      ).eq("is_deleted", false).maybeSingle(),
    );
    if (!plan) throw new KrogerError("plan_not_found", 404);
    const existing = checked(
      await this.admin.from("kroger_exports").select("id,status,created_at").eq(
        "user_id",
        this.userId,
      ).eq("environment", this.client.config.environment).eq("plan_id", planId)
        .maybeSingle(),
    );
    if (existing) return { receipt: existing }; // Never replay a sent, sending, or unknown batch.
    const token = await this.customerToken();
    const changed = [];
    for (let offset = 0; offset < lines.length; offset += 5) {
      const products = await Promise.all(
        lines.slice(offset, offset + 5).map((line) =>
          // A product the filter no longer returns is a line to review, not a
          // failed export: it joins `changed` so the shopper sees which one.
          this.client.product(line.upc, store, mode, token).catch((e) => {
            if (e instanceof KrogerError && e.code === "product_unavailable") {
              return unavailableProduct(line.upc);
            }
            throw e;
          })
        ),
      );
      for (const product of products) {
        const expected = body.items.filter((i: any) => i.upc === product.upc);
        if (
          !product.available ||
          expected.some((e: any) =>
            e.price !== product.price || e.size !== product.size
          )
        ) changed.push(product);
      }
    }
    if (changed.length) return { changed }; // No cart write has happened. Review before trying again.
    const fp = await fingerprint(store, lines);
    const inserted = await this.admin.from("kroger_exports").insert({
      id,
      user_id: this.userId,
      plan_id: planId,
      environment: this.client.config.environment,
      fingerprint: fp,
      payload: { store, lines },
      status: "sending",
    });
    if (inserted.error) {
      if (inserted.error.code === "23505") {
        const receipt = checked(
          await this.admin.from("kroger_exports").select("id,status,created_at")
            .eq("user_id", this.userId).eq(
              "environment",
              this.client.config.environment,
            ).eq("plan_id", planId).maybeSingle(),
        );
        if (receipt) return { receipt };
      }
      throw new KrogerError("storage_unavailable", 503);
    }
    let status = "sent";
    try {
      await this.client.add(lines, token);
    } catch {
      status = "unknown";
    }
    // If persisting the outcome fails, the durable 'sending' row still blocks replay.
    checked(
      await this.admin.from("kroger_exports").update({ status }).eq("id", id)
        .eq("user_id", this.userId),
    );
    return { receipt: { id, status } };
  }
}
