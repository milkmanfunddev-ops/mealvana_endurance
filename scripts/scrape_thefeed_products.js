#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const ENDPOINT =
  process.env.THEFEED_STOREFRONT_ENDPOINT ||
  "https://thefeed.myshopify.com/api/2024-10/graphql.json";
const TOKEN =
  process.env.THEFEED_STOREFRONT_TOKEN ||
  "ee5c8524ec06e62d02701486c1b3a1f3";
const OUTPUT_PATH =
  process.argv[2] ||
  path.join(process.cwd(), "output", "thefeed_products.json");

const PRODUCTS_QUERY = `
  query ProductsPage($first: Int!, $after: String) {
    products(first: $first, after: $after, sortKey: ID) {
      edges {
        cursor
        node {
          id
          handle
          title
          vendor
          productType
          tags
          totalInventory
          availableForSale
          onlineStoreUrl
          updatedAt
          featuredImage {
            url
          }
          priceRange {
            minVariantPrice {
              amount
              currencyCode
            }
            maxVariantPrice {
              amount
              currencyCode
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function graphqlRequest(query, variables, attempt = 0) {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-shopify-storefront-access-token": TOKEN,
    },
    body: JSON.stringify({ query, variables }),
  });

  const json = await res.json();

  if (!res.ok || json.errors) {
    const errors = json.errors || [{ message: `HTTP ${res.status}` }];
    const throttled = errors.some(
      (e) =>
        typeof e.message === "string" &&
        e.message.toLowerCase().includes("throttle"),
    );

    if (throttled && attempt < 6) {
      const waitMs = 500 * (attempt + 1);
      await sleep(waitMs);
      return graphqlRequest(query, variables, attempt + 1);
    }

    throw new Error(`GraphQL request failed: ${JSON.stringify(errors)}`);
  }

  return json;
}

async function fetchAllProducts() {
  const products = [];
  let after = null;
  let page = 0;

  while (true) {
    const response = await graphqlRequest(PRODUCTS_QUERY, {
      first: 250,
      after,
    });

    const connection = response.data.products;
    const edges = connection.edges || [];
    const pageInfo = connection.pageInfo;
    const throttle = response.extensions?.cost?.throttleStatus;

    for (const edge of edges) {
      products.push(edge.node);
    }

    page += 1;
    console.error(
      `Fetched page ${page}: +${edges.length} (total ${products.length})`,
    );

    if (!pageInfo.hasNextPage) {
      break;
    }

    after = pageInfo.endCursor;

    if (throttle && throttle.currentlyAvailable < 120) {
      await sleep(300);
    }
  }

  return products;
}

async function main() {
  const startedAt = new Date().toISOString();
  const products = await fetchAllProducts();
  const payload = {
    source: "thefeed.myshopify.com Storefront GraphQL",
    endpoint: ENDPOINT,
    fetchedAt: new Date().toISOString(),
    startedAt,
    totalProducts: products.length,
    products,
  };

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(payload, null, 2));

  console.log(`Wrote ${products.length} products to ${OUTPUT_PATH}`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
