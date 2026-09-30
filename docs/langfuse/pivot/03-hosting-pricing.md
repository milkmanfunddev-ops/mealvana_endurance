# Langfuse: Cloud vs self-hosting (as of 2026-09-30)

Primary sources only (langfuse.com pages, their docs-search API, and the acquisition announcement).
Anything that is my own estimate is marked **estimate**.

Context: since 2026-01-16 Langfuse belongs to ClickHouse, Inc. The company says the roadmap, the
open-source license, self-hosting and Langfuse Cloud all continue unchanged.
Sources: https://langfuse.com/blog/joining-clickhouse ,
https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability .
The security page now lists `security@clickhouse.com` as the contact.

## 1. Cloud plans

Source: https://langfuse.com/pricing

| | Hobby | Core | Pro | Enterprise |
|---|---|---|---|---|
| Price | $0 | $29/mo | $199/mo | $2,499/mo |
| Included units | 50k/mo (hard cap, no overage) | 100k/mo | 100k/mo | 100k/mo |
| Overage | none | graduated, see below | graduated | graduated, custom with a yearly contract |
| Data access window | 30 days | 90 days | 3 years | 3 years |
| Users | 2 | unlimited | unlimited | unlimited |
| Projects | unlimited | unlimited | unlimited | unlimited |
| RBAC | org-level | org-level | org-level; project-level with the Teams add-on | org + project-level |
| SSO | Google / AzureAD / GitHub sign-in | same | Enterprise SSO + enforcement with the Teams add-on | Enterprise SSO (Okta etc.), enforcement |
| SCIM | no | no | no | yes |
| Audit log viewer | no | no | no | yes |
| Data retention policy (auto-delete after N days) | no | no | yes | yes |
| Blob storage export | no | no | with the Teams add-on | yes |
| Annotation queues | 1 | 3 | unlimited | unlimited |
| Alerts | 2 | 20 | 50 | 100 |
| HIPAA (BAA) | no | no | yes | yes |
| SOC 2 / ISO 27001 reports | no | no | yes | yes |
| Support | GitHub community | in-app, 48h SLO | in-app, 48h (24h with Teams) | named engineer, custom SLA, Slack channel |
| Regions | US, EU, JP | US, EU, JP | US, EU, JP, HIPAA | US, EU, JP, HIPAA; AWS PrivateLink |

- **Teams add-on for Pro:** $300/mo. Adds Enterprise SSO, SSO enforcement, fine-grained (project-level) RBAC and Slack support.
- **Graduated overage, all paid plans:** first 100k included; 100k–1M $8.00 per 100k; 1M–10M $7.00; 10M–50M $6.50; 50M+ $6.00 per 100k.
- **Discounts:** early-stage startups 50% off for the first year; non-profits $199/mo in credits; OSS projects $300/mo for the first year; research/students up to 100% off.
- **Unit** = traces + observations + scores ingested per billing period. Example from the docs: 20,070 traces + 119,500 observations + 561 scores = 140,131 units per month. https://langfuse.com/docs/administration/billable-units
  - One Vana chat turn with ~8 spans plus 2–3 judge scores comes to roughly 10–12 units. At 100k units a month that is about 8–10k turns. (**Estimate.**)
- **Data retention:** can be set per project (minimum 3 days) on Pro and Enterprise, or on self-hosted EE. Without a policy, Cloud deletes nothing and simply enforces the plan's access window; self-hosted keeps data forever. https://langfuse.com/docs/administration/data-retention
- **In-app "Langfuse Assistant"** (the agent that debugs traces in the video): Cloud only, public beta on every plan, **not available self-hosted**. https://langfuse.com/docs/langfuse-assistant

### Cloud public API rate limits
Source: https://langfuse.com/faq/all/api-limits

| Resource | Hobby | Core | Pro/Team/Enterprise |
|---|---|---|---|
| Tracing ingestion (batch / OTEL) | 1,000/min | 4,000/min | 20,000/min |
| General API | 30/min | 100/min | 1,000/min |
| Datasets | 100/min | 200/min | 1,000/min |
| Metrics API v2 | 100/day | 100/hour | 500/hour |
| Trace deletion | 50/day | 200/day | 1,000/day |
| Prompts | unlimited | unlimited | unlimited |
| Legacy read APIs | 15/min | 30/min | 100/min |

Payload limit: 5 MB per request and 5 MB per response. When a limit is hit the API returns 429 with `Retry-After`. Self-hosted has no hard limits; throughput depends on your own infrastructure. Enterprise can negotiate custom limits.

**Implication for us:** on Hobby, 30 req/min on the general API and 100/day on the Metrics API are tight for an eval harness (the `mealvana_eval` Next.js app) that reads traces back. Core is the realistic minimum for that.

## 2. Self-hosting

### Architecture
Source: https://langfuse.com/self-hosting

- Two app containers: **langfuse-web** (UI and APIs) and **langfuse-worker** (async ingestion processing).
- Four data stores:
  - **Postgres** (transactional data)
  - **ClickHouse** (traces, observations, scores)
  - **Redis/Valkey** (cache and queue)
  - **S3-compatible blob storage** (raw events plus multimodal attachments such as images)
- Optional: an LLM connection for the playground and LLM-as-judge.
- v4 minimums: ClickHouse ≥ 25.12 (26.4 recommended), Postgres ≥ 15, Redis ≥ 7.0.

### Deployment options

| Option | Support | Notes |
|---|---|---|
| Docker Compose | official | "lacks high-availability, scaling capabilities, and backup functionality". Recommended VM: **4 cores, 16 GiB RAM (e.g. t3.xlarge), 100 GiB disk**. https://langfuse.com/self-hosting/deployment/docker-compose |
| Kubernetes (Helm) | official | Can bundle the data stores or point at managed ones. For production, managed S3/GCS/Azure Blob is recommended over the bundled SeaweedFS. https://langfuse.com/self-hosting/deployment/kubernetes-helm |
| AWS / Azure / GCP Terraform | official | e.g. `langfuse/langfuse-terraform-aws` (EKS plus managed services; needs a domain you control). https://langfuse.com/self-hosting/deployment/aws |
| Railway, Render | community, best-effort | **The Railway template is still v3**; no v4 template yet. https://langfuse.com/self-hosting/deployment/railway |

### Realistic monthly cost (**estimate**, AWS us-east list prices; Langfuse publishes no figure)
- **Compose on one t3.xlarge:** about $120/mo on-demand, plus about $8 for 100 GB gp3, plus S3 (pennies at our volume). That comes to roughly **$130–150/mo**. It has no high availability, and you build the backups yourself.
- **Terraform/EKS with managed services:** the EKS control plane alone is about $73/mo. Add nodes, RDS Postgres, ElastiCache, ClickHouse nodes or ClickHouse Cloud, and a load balancer. Expect roughly **$400–1,000+/mo** before anyone's time.
- **The bigger cost is ops time:** upgrades, ClickHouse disk growth, backups and security patches.

### Upgrade burden
Sources: https://langfuse.com/self-hosting/upgrade/versioning ,
https://langfuse.com/self-hosting/upgrade/upgrade-guides/upgrade-v3-to-v4

- Semver. A major version bumps only for infrastructure changes or public API removals. Cloud deploys continuously; self-hosters pick their own cadence and are told to "keep the server up to date".
- **The v3 to v4 upgrade (current) is heavy:**
  - Upgrade ClickHouse to ≥ 25.12 first.
  - Run in dual-write mode, then backfill historic data. The ClickHouse disks need about **3x the current data volume** for the backfill.
  - Then move to the new `events_full` / `events_core` tables.
  - No downtime is needed if you follow the three steps.
  - Helm users with bundled stores must first move the chart from v1 to v2.
  - Once v4 defaults apply, Python SDK ≤ v2 and JS SDK ≤ v3 are rejected at ingestion.
  - Some v3 features have a published deprecation date of **2026-11-16**.
- Past majors v1→v2 and v2→v3 also changed infrastructure (v3 added ClickHouse, Redis and S3).

### License: MIT OSS vs Enterprise Edition
Sources: https://langfuse.com/open-source , https://langfuse.com/self-hosting/license-key ,
https://langfuse.com/pricing-self-host

- Everything outside `/ee` folders is MIT. The docs say: "All product capabilities—tracing, evaluations, prompt management, experiments, annotation, the playground, and more—are MIT licensed without any usage limits."
- So all of these are **free self-hosted**: annotation queues, LLM-as-judge and code evaluators, the playground, prompt experiments, datasets, dashboards, and org-level RBAC with Owner/Admin/Member/Viewer roles.
- **Gated behind `LANGFUSE_EE_LICENSE_KEY` (self-hosted):**
  - project-level RBAC roles
  - protected prompt labels
  - data retention policies
  - audit log viewer (the `audit_logs` Postgres table is written regardless of plan, and OSS users can query it directly; https://langfuse.com/self-hosting/configuration/hardening)
  - server-side ingestion masking
  - UI customization
  - organization creators
  - Org Management API and SCIM
  - Instance Management API
- Self-hosted Enterprise has custom pricing and bundles ClickHouse Cloud, BYOC or Private. It adds named support and SOC 2 / ISO reports.
- **Not available self-hosted at any price:** the in-app Langfuse Assistant.
- SSO: self-hosted OSS supports email/password and SSO providers through env config (https://langfuse.com/self-hosting/security/authentication-and-sso). The EE-gated items are SCIM and enforcement-related admin APIs.
- Telemetry: anonymized usage telemetry is on by default. Opt out with `TELEMETRY_ENABLED=false`. EE-licensed instances always report it.

## 3. Running both, and migrating

- **Both at once is technically possible.** Langfuse's OTEL guide shows several span processors on one `TracerProvider`, and every processor sees every span. https://langfuse.com/faq/all/existing-otel-setup
  - The JS `LangfuseSpanProcessor` takes its own `publicKey`, `secretKey` and `baseUrl`, so two processors (Cloud and self-hosted) can sit side by side. This is inferred from the constructor; **the docs do not document a dual-Langfuse setup**.
  - Python has an *experimental* multi-project mode keyed on the public key.
  - Caveats: double ingestion (the Cloud side is billed); scores, annotations, prompts and datasets created in one UI do not appear in the other; prompt fetching must pick one source of truth; and the default span filter applies to each processor.
  - Our edge functions (Deno) would need both sets of keys.
- **Migration path.** The official cookbook migrates project to project via the API: https://langfuse.com/guides/cookbook/example_data_migration
  - Listed use cases include "self-hosted Langfuse to Langfuse Cloud" and moving between regions.
  - **Migrated:** score configs, custom models, prompts (all versions), traces and observations (via OTLP, so timestamps are kept), scores, datasets.
  - **Not migrated:** LLM-as-judge evaluator configs, custom dashboards, users/RBAC/SSO, project settings, historic dataset run items.
  - Re-ingesting into Cloud **counts as billable units**.
  - Ongoing export: blob-storage export to S3/GCS/Azure in Parquet/CSV/JSON(L), every 20 min up to weekly. Available on self-hosted, Enterprise, or Pro with Teams. https://langfuse.com/docs/api-and-data-platform/features/export-to-blob-storage
  - The Langfuse video also says "no lock-in" (OTEL in; REST, metrics and observations APIs plus blob export out).
- **Web UI for Xuan:** both Cloud and self-hosted serve the **same web UI**; the public repo is the Cloud codebase. She can log in, review traces, use annotation queues and edit prompts in either. On Cloud Hobby she would be user 2 of 2; Core and up have unlimited users. Self-hosted OSS has unlimited users too. The Assistant chat panel exists only on Cloud.

## 4. Security and privacy (nutrition data, meal photos)

Sources: https://langfuse.com/security , https://langfuse.com/security/hipaa ,
https://langfuse.com/self-hosting/security/data-masking , https://langfuse.com/docs/observability/features/masking

- **Cloud:**
  - SOC 2 Type II and ISO 27001 audited yearly, with an annual third-party pentest. Reports are available on Pro and up.
  - GDPR with a DPA.
  - Runs on AWS plus ClickHouse Cloud in isolated regional environments (US/EU/JP), encrypted at rest and in transit.
  - Multi-tenant, with project-scoped isolation and project-scoped API keys.
- **HIPAA:**
  - A separate region, `hipaa.cloud.langfuse.com` (AWS us-west-2 Oregon).
  - Pro plan or higher, BAA signed via DocuSign, and it needs a *fresh account in that region*.
  - Self-hosted needs no BAA from Langfuse; you implement the safeguards yourself.
  - Athlete nutrition data is probably not PHI for us (we are not a covered entity). Worth a one-line check with Xuan or counsel rather than assuming.
- **Masking:**
  - Client-side `mask` function on the SDK / `LangfuseSpanProcessor` works on every plan and in OSS. Data is redacted before it leaves the app. This is the right tool for names, emails and free-text health notes.
  - Server-side ingestion masking (an HTTP callback) is **EE-only** when self-hosting.
- **Meal photos:**
  - The SDKs extract base64 data-URI images and upload them to Langfuse's object storage, linked to the trace (https://langfuse.com/docs/observability/features/multi-modality).
  - On Cloud that means photos leave our Supabase and sit in Langfuse's S3 for the plan's access window (3 years on Pro) unless a retention policy is set.
  - Options: pass signed Supabase URLs instead of base64, mask the image field, or set a short retention on Pro.
- **Deletion:** a trace deletion API exists and is rate-limited (50/day on Hobby to 1,000/day on Pro). Retention policies delete nightly.

## 5. Tradeoffs in one table

| | Cloud (Core $29 / Pro $199) | Self-host OSS |
|---|---|---|
| Money | $29–199/mo plus units | about $130/mo (Compose) to $500+/mo (HA) in infrastructure (**estimate**) |
| Ops | none | upgrades (v4 is heavy), backups, ClickHouse disk, patching |
| Features | everything, including the Assistant; retention needs Pro | everything except the Assistant; retention, project RBAC and server-side masking need an EE key |
| Data residency | US/EU/JP/HIPAA regions, data leaves our infrastructure | all data stays in our AWS account |
| Rate limits | per plan (see above) | none beyond our infrastructure |
| Xuan's UI | yes | yes (we host and secure it) |
