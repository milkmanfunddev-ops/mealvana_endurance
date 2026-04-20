#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const items = JSON.parse(fs.readFileSync(path.join(__dirname, 'data', 'catalog_items_export.json'), 'utf8'));
const products = new Map();

for (const item of items) {
  const pid = item.shopify_product_id;
  if (!products.has(pid)) {
    products.set(pid, {
      shopify_product_id: pid,
      title: item.title,
      brand: item.brand,
      product_type: item.product_type,
      tags: (item.tags || []).join(', '),
      ingredients: item.ingredients || null,
      handle: item.handle,
    });
  } else {
    const p = products.get(pid);
    if (!p.ingredients && item.ingredients) p.ingredients = item.ingredients;
  }
}

const arr = Array.from(products.values());
fs.writeFileSync(path.join(__dirname, 'data', 'unique_products.json'), JSON.stringify(arr, null, 2));
console.log('Unique products: ' + arr.length);

// Product type breakdown
const types = {};
for (const p of arr) {
  const t = p.product_type || '(none)';
  types[t] = (types[t] || 0) + 1;
}
console.log('\nShopify product_type breakdown:');
Object.entries(types).sort((a, b) => b[1] - a[1]).forEach(([t, c]) => console.log('  ' + t + ': ' + c));

// Brand breakdown
const brands = {};
for (const p of arr) {
  const b = p.brand || '(none)';
  brands[b] = (brands[b] || 0) + 1;
}
console.log('\nTop 30 brands:');
Object.entries(brands).sort((a, b) => b[1] - a[1]).slice(0, 30).forEach(([b, c]) => console.log('  ' + b + ': ' + c));
