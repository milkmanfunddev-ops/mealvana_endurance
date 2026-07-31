#!/usr/bin/env node
// Generate a landing-page changelog entry from git commits using Claude, then
// publish it as a Sanity `changelog` document (which the me_website_new landing
// page renders). Zero-dependency: uses fetch + git only.
//
// Trigger: GitHub Action on push/merge to `main` (see
// .github/workflows/changelog-on-main.yml).
//
// Env:
//   AI_GATEWAY_API_KEY   (required) — generation via the Vercel AI Gateway
//                         (OpenAI-compatible; the same key the app's edge
//                         functions use to call Claude). No raw Anthropic key.
//   AI_GATEWAY_BASE_URL  (optional, default https://ai-gateway.vercel.sh/v1)
//   CHANGELOG_MODEL      (default anthropic/claude-sonnet-4.6)
//   SANITY_WRITE_TOKEN   (required) — publish
//   SANITY_PROJECT_ID    (default sigrvh1t)
//   SANITY_DATASET       (default production)
//   FROM_REF, TO_REF     git range (default <TO>~30..HEAD). The Action passes
//                         github.event.before .. github.sha.
//   VERCEL_DEPLOY_HOOK   (optional) — POSTed after publish to rebuild the site
//   DRAFT=1              publish as a Sanity draft (drafts.*) for review instead of live
//   DRY_RUN=1            print the document, do not write to Sanity

import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

const PROJECT_ID = process.env.SANITY_PROJECT_ID || "sigrvh1t";
const DATASET = process.env.SANITY_DATASET || "production";
const MODEL = process.env.CHANGELOG_MODEL || "anthropic/claude-sonnet-4.6";
const GATEWAY_BASE = (process.env.AI_GATEWAY_BASE_URL || "https://ai-gateway.vercel.sh/v1").replace(/\/$/, "");

function appVersion() {
  const m = readFileSync("pubspec.yaml", "utf8").match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m);
  if (!m) throw new Error("Could not read version from pubspec.yaml");
  return m[1];
}

function commitSubjects() {
  const to = process.env.TO_REF || "HEAD";
  const from = process.env.FROM_REF && !process.env.FROM_REF.startsWith("0000") ? process.env.FROM_REF : `${to}~30`;
  return execSync(`git log --no-merges --pretty=format:%s ${from}..${to}`, { encoding: "utf8" }).trim();
}

async function generateNotes(version, commits) {
  const system =
    "You write concise, user-facing release notes for the Mealvana Endurance " +
    "iOS/Android app's marketing landing page. ONLY include changes an end user " +
    "would notice or care about. Group them into whatsNew (headline new features), " +
    "improvements (enhancements / quality-of-life), and bugFixes. SKIP internal " +
    "commits: chore, ci, refactor, test, build, codegen, docs, dependency bumps. " +
    "Bullets must be short, benefit-oriented, and free of jargon, file names, or " +
    "ticket IDs. Write a single-sentence `title` summarizing the release and pick a " +
    "`label` from exactly: Major Update, New Feature, Bug Fix, Latest. Respond with " +
    'STRICT JSON only: {"title":"","label":"","whatsNew":[],"improvements":[],"bugFixes":[]}';
  // Vercel AI Gateway, OpenAI-compatible endpoint (Bearer auth, chat/completions).
  const res = await fetch(`${GATEWAY_BASE}/chat/completions`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${process.env.AI_GATEWAY_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1500,
      messages: [
        { role: "system", content: system },
        { role: "user", content: `Version ${version}.\nCommit subjects:\n${commits}` },
      ],
    }),
  });
  if (!res.ok) throw new Error(`AI Gateway ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = data.choices?.[0]?.message?.content || "";
  return JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
}

// Convert a list of strings into Sanity portable-text blocks.
function blocks(items, prefix) {
  return (items || []).filter(Boolean).map((t, i) => ({
    _type: "block",
    _key: `${prefix}${i}`,
    style: "normal",
    markDefs: [],
    children: [{ _type: "span", _key: `${prefix}s${i}`, text: String(t), marks: [] }],
  }));
}

async function publish(version, notes) {
  // The dataset's anonymous read grant is `_id in path("*")`, which matches
  // only dot-free single-segment ids. A semver like "1.22.0" contains dots, so
  // an id such as `changelog-v1.22.0` is permission-omitted for the public
  // site. Use dashes in the id; the `version` field keeps the dotted value.
  const baseId = `changelog-v${version.replace(/\./g, "-")}`;
  const doc = {
    _id: process.env.DRAFT ? `drafts.${baseId}` : baseId,
    _type: "changelog",
    version,
    title: notes.title,
    label: ["Major Update", "New Feature", "Bug Fix", "Latest"].includes(notes.label) ? notes.label : "Latest",
    releaseDate: new Date().toISOString().slice(0, 10),
    whatsNew: blocks(notes.whatsNew, "w"),
    improvements: blocks(notes.improvements, "i"),
    bugFixes: blocks(notes.bugFixes, "f"),
  };
  if (process.env.DRY_RUN) {
    console.log(JSON.stringify(doc, null, 2));
    return;
  }
  const res = await fetch(`https://${PROJECT_ID}.api.sanity.io/v2021-06-07/data/mutate/${DATASET}`, {
    method: "POST",
    headers: { authorization: `Bearer ${process.env.SANITY_WRITE_TOKEN}`, "content-type": "application/json" },
    body: JSON.stringify({ mutations: [{ createOrReplace: doc }] }),
  });
  if (!res.ok) throw new Error(`Sanity ${res.status}: ${await res.text()}`);
  console.log(`Published changelog v${version} -> Sanity ${PROJECT_ID}/${DATASET} (${doc._id}).`);
  if (process.env.VERCEL_DEPLOY_HOOK) {
    await fetch(process.env.VERCEL_DEPLOY_HOOK, { method: "POST" });
    console.log("Pinged Vercel deploy hook.");
  }
}

const version = appVersion();
const commits = commitSubjects();
if (!commits) {
  console.log("No non-merge commits in range; nothing to publish.");
  process.exit(0);
}
if (!process.env.AI_GATEWAY_API_KEY) throw new Error("AI_GATEWAY_API_KEY is required");
if (!process.env.SANITY_WRITE_TOKEN && !process.env.DRY_RUN) {
  throw new Error("SANITY_WRITE_TOKEN is required");
}
const notes = await generateNotes(version, commits);
await publish(version, notes);
