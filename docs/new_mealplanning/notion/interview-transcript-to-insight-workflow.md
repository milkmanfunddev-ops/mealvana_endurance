# Interview Transcript → Insight

**Source URL:** https://app.notion.com/p/320e3fdb754c819f993ae20078f18dca
**Ancestor path:** AI Workflows (data source) → AI Workflows (database) → 💬 AI Library
**Snapshot date:** 2026-03-18T16:26:11.443Z
**Comments/discussions:** none found (fetched with `include_discussions: true`; no discussion markers present)

**Note:** This is an internal AI-automation workflow specification (a Claude-executable process document), not a user or coach interview. Included per fetch instructions.

## Properties

| Property | Value |
|---|---|
| Name | Interview Transcript → Insight |
| Status | Active |
| Type | Workflow |

## Content

**Purpose:** AI-executable workflow to process a raw interview transcript into a structured insight document in the 📋 Interviews database, extracting key themes, insights, relationship notes, and populating all database properties.

**Output:** A new page in the 📋 Interviews database with structured content and populated properties, ready for human review.

**Trigger:** A task in the AI Task Queue like "Process Claudia McCoy interview transcript" or an ad-hoc request like "Turn this interview into insights" with a link to a raw transcript page.

---

## AI Capabilities & Boundaries

**Claude CAN:**
- Parse the transcript to identify participants, date, duration, and format
- Extract key themes, insights, and notable quotes
- Identify the interviewee and link to their CRM contact page
- Populate all Interviews database properties (Themes, Role, Source, etc.)
- Write the opening insights paragraph, Key Themes, conditional sections, and Relationship Notes
- Link the raw transcript page via the Raw Transcripts relation
- Store the current Claude chat link in the Claude Chat Link property
- Update the CRM page with synthesized interview insights and pain points
- Update AI Task Queue status (if triggered from queue)

**Claude CANNOT:**
- Set the Status to "Processed" — human must review and promote from "Completed" to "Processed"
- Create Problem Statements (excluded from this workflow per instructions)
- Invent or infer information not present in the transcript
- Make judgments about product direction based on a single interview

---

## Analysis Persona

When analyzing the transcript in Step 3, Claude adopts the following persona and rules:

> **You are a senior customer research analyst and an expert at identifying clear, evidence-based themes from interview transcripts.** Your analysis will directly inform high-risk product decisions. Your goal is to find patterns that go beyond surface-level feedback and are grounded in real user language and behavior.
>
> **Task:** Identify all key themes related to user pain points, motivations, behaviors, or unmet needs.
>
> **IMPORTANT:** Do NOT share superficial themes. Dig deep and find nuanced sub-themes supported by a lot of detail, backstory.
>
> **Rules:**
> - Use only the content from the transcript.
> - Do not generalize or synthesize participants' language.
> - Avoid themes like "users want ease of use" unless the user said those exact words.
> - If unsure about a theme, still include it but flag confidence as "low."

This persona applies specifically to Step 3 (Analyze the Transcript). The rest of the workflow (metadata extraction, page creation, handoff) follows the standard operational voice.

---

## Execution Steps

### Step 1: Locate & Load the Raw Transcript
**Parse the transcript reference** from the task or request. This could be a Notion page link, a coach name, or a transcript title.

**If a direct link is provided:**
```javascript
Fetch the page using Notion fetch tool
```

**If only a name or description is provided:**
```javascript
Search: Raw Transcripts database (collection://7857998c-c0cb-41ce-be0f-cc3dbeb03a7f)
Query: [name or description]
```

**Load from the transcript page:**
- Full transcript content
- Transcript Name, Date, Source Type

**Stop Conditions:**
- If transcript not found → Report to human, ask for clarification or a direct link
- If transcript content is empty or too short to extract insights → Flag and ask human

---

### Step 2: Identify the Interviewee & Load CRM Context
**Extract the interviewee name** from the transcript. Look for the non-team speaker (not Xuan, not Lee, not Rui) who is the primary subject of the interview.

**Search the CRM database:**
```javascript
Database: CRM (collection://2e3e3fdb-754c-8036-b775-000ba0d66a9f)
Search: [Interviewee Name]
```

**Load from CRM page (if found):**
- Name, Company, Role
- Any existing context (this helps avoid redundant info and enriches the insight)

**If not found in CRM:**
- Proceed without CRM link — note in handoff that CRM entry may need to be created
- Still extract whatever context about the interviewee is available from the transcript itself

---

### Step 3: Analyze the Transcript
Activate the **Analysis Persona** (defined above). Read the full transcript and extract the following:

**Interview Metadata:**
- Date (from transcript properties or content)
- Approximate duration (look for cues like "we went over X minutes" or infer from length/content)
- Participants (list all speakers)
- Format (e.g., "Demo of athlete app + coach mode, followed by open discussion")

**Opening Insights Paragraph** — Write a dense, scannable summary (paragraph format, not bullets) covering the most important takeaways. This becomes the **first thing on the page** (no header). It should be written so someone clicking into the page can immediately understand what this interview revealed. Include specific numbers, preferences, and actionable insights.

Style reference — aim for this density level:
> *"Coaches prefer athlete-led plan creation with coach review, not coach-dictated plans. Athletes hit a cognitive wall translating gram targets into product mixes. Training-day logging in TP is freeform and inconsistent — standardized format saves coach time. Coaches deliberately ramp intake targets over weeks (40→50→80g) for gut adaptation — no tool supports this…"*

**Key Themes** — Identify 4-10 themes. For each theme:

**Theme titles should be the actual insight, not a generic category.** Do not title a theme "Race Day Fueling" or "Coach-Athlete Workflow." Instead, title it with the specific finding: "The 'Math Overwhelm' Moment at Product Translation" or "Athlete-Led Plan Creation Is a Coaching Philosophy, Not a Preference."

**Ground each theme in direct evidence.** Use italicized direct quotes from the transcript to support the theme. Each theme should include 1-3 key quotes that prove the insight is real. This is not optional — unsupported themes are superficial themes.

**Confidence tagging is lightweight.** Do NOT tag every theme with a confidence level. Only flag confidence explicitly when it is "low" — meaning the theme is based on a single brief mention or is inferred rather than stated. Append "Single mention — low confidence" or similar at the end of that theme's summary. High- and medium-confidence themes need no annotation.

Use the existing Themes multi-select options as **database tags** where they fit:
- Nutrition Communication
- Meal Planning
- Race Day Fueling
- Coach-Athlete Workflow
- Training Integration
- Pricing/Willingness to Pay

But remember: these tags categorize, they don't dictate the theme title. A theme tagged "Race Day Fueling" might be titled "Recovery Nutrition Is a Logistics Problem, Not a Knowledge Problem."

**Conditional Sections** — Not every interview has the same shape. Include additional sections when the transcript warrants them:
- **Prototype & Demo Feedback** — When the interview includes a demo or walkthrough of a Mealvana feature/prototype. Capture specific reactions, feature requests, and UI feedback as concise bullets.
- **Pilot Coach Program / Partnership** — When the interviewee accepts or discusses joining the pilot program. Capture: acceptance, number of athletes they'd bring, any conditions or prior tool experience.
- **Product/Feature Requests** — When the interviewee makes specific, actionable requests that don't fit neatly into a theme (e.g., "I want distance markers, not just time").

Only include sections that are substantively present in the transcript. Do not create empty sections.

**Relationship Notes** — Extract signals about the interviewee's engagement, personality, and relationship trajectory:
- How did we meet / get connected?
- Engagement signals (went over time, shared materials, asked for follow-up)
- Personal details that inform the relationship (background, coaching style, tools/brands used, credentials)
- Any commitments made (by us or by them)
- Follow-up timeline discussed

---

### Step 4: Ask Human for Clarification (if needed)
**Before creating the insight page, check for gaps:**
- Is the interviewee's Role clear? (Coach / Athlete / Nutritionist / Industry Partner / Other)
- Is the Source clear? (Endurance Exchange 2026 / Cold Outreach / Referral / User Feedback / Other)
- Is the Interview Type clear? (Discovery is the default)

**If all are clear from context**, skip this step and proceed.
**If ambiguous**, use the ask_user_input tool to confirm the unclear fields. Don't ask about things that are obvious from the transcript.

---

### Step 5: Create the Insight Page
**Create a new page in the 📋 Interviews database:**
```javascript
Data Source: collection://1d10c4a1-c780-4ae0-98e9-ea0363dc4806
```

**Properties to populate:**

| Property | Value |
|---|---|
| Interviewee (title) | `[Name] — [number]` (e.g., "Claudia McCoy — 1" for first interview, increment for repeat interviewees) |
| Status | `Completed` (human promotes to Processed after review) |
| Interview type | `Discovery` (or as determined in Step 4) |
| Role | As determined from transcript (Coach, Athlete, etc.) |
| Source | As determined from transcript or context |
| Themes | Multi-select from the available options that match |
| Date | From the transcript's date property |
| CRM Contact | Relation to CRM page (if found in Step 2) |
| Raw Transcripts | Relation to the source transcript page |
| Claude Chat Link | URL of the current Claude conversation |

**Note:** There is no Key Insights database property. The dense insights summary lives as the opening paragraph of the page content.

**Page Content Structure:**
```markdown
[Dense opening paragraph — the insights summary from Step 3. No header. First thing the reader sees.]

## Interview Summary
**Date:** [Date] — [Call type, e.g., Zoom Call]
**Duration:** ~[X] minutes ([note if went over scheduled time])
**Participants:** [List all]
**Format:** [Brief description of what happened in the call]

## Key Themes
### [Specific Insight as Title — NOT a generic category]
[1-3 sentence summary with *italicized direct quotes* as evidence. Be specific — include numbers, product names, and concrete examples from the transcript.]

### [Next Specific Insight Title]
[...]

[Continue for each theme. Flag "low confidence" only where needed.]

## Prototype & Demo Feedback (if applicable)
- [Bullet points capturing reactions, requests, and specific UI feedback]

## Pilot Coach Program (if applicable)
- [Acceptance, athlete count, conditions, prior tool experience]

## Relationship Notes
- [Bullet points capturing engagement signals, personal context, tools/brands used, commitments, and follow-up plans]
```

**Stop Conditions:**
- If the Notion create fails → Report error to human
- If the transcript is ambiguous on a critical insight → Include it with confidence flagged as "low" rather than omitting it

---

### Step 6: Update the CRM Page
**Skip this step if** no CRM contact was found in Step 2.

This step flows interview insights back into the coach's CRM page so the relationship record stays current without requiring a separate manual update.

**6a. Update the Pain points property**

Read the existing Pain points text on the CRM page. Append new pain points surfaced in the interview — do not overwrite what's already there. Write new entries in the same concise, third-person style as the existing content.

Example format:
> *Existing:* "Lana thinks the nutrition part of the training deserves to live in a separate place, not inside TP."
> *Appended:* "Athletes hit a cognitive wall translating gram targets into product counts — the 'math overwhelm' moment. Training-day nutrition logging in TP is freeform and inconsistent, costing coach time. Coaches deliberately ramp carb targets over weeks for gut adaptation but no tool supports progressive loading."

If the interview did not surface new pain points beyond what's already captured, leave the property unchanged.

**6b. Append to the `## 🎤 Interviews` section on the CRM page**

**First, check if a `## 🎤 Interviews` section already exists on the CRM page.** This is the standard section where all interview entries live on CRM pages.
- **If the section exists:** Append the new interview entry at the bottom of it, before the next `---` or `##` section.
- **If the section does not exist:** Create a `## 🎤 Interviews` section. Place it **above** `## 📧 Correspondence` if that section exists, otherwise at the end of the page content.

**Do NOT create a separate section** with a different name (e.g., `## 🎙️ Interview Insights`). All interview entries belong under the single `## 🎤 Interviews` section.

**Critical:** When building the `old_str` for `update_content`, copy the exact section header and body text from the fetched CRM page content. Do not type section headers from memory — emoji variants (e.g., 🎙️ vs 🎤) cause silent match failures.

**Entry format for each interview:**
```markdown
### [Interview title, e.g., "Discovery Interview 2 — March 5, 2026"]
[3-5 sentence synthesis of the most important findings from this interview, written for CRM context — focus on what matters for the ongoing relationship and product engagement, not the full research detail.]

**Key signals:**
- [2-4 bullets: most actionable pain points, feature reactions, or engagement signals]

**Full analysis:** [Link to insight page in Interviews database]
```

Each entry is a `###` sub-heading under the `## 🎤 Interviews` parent. Multiple interviews accumulate as sequential entries — the section grows over time as more interviews are processed.

This section is intentionally lighter than the full insight page — it's a relationship-oriented summary, not a duplicate of the research analysis.

**6c. Update CRM page sections with new information from the interview**

Interviews often surface new biographical, professional, or relationship details about the coach that belong in the CRM page's content sections — not just in Pain points or the Interviews log. When the transcript reveals information that fills gaps or updates existing content on the CRM page, update the relevant sections.

**Read the existing CRM page content** (fetched in Step 2) and compare it against what the interview revealed. Update the following sections when new information is present:

**`📋 Research` → `Company Overview` toggle:**
- Fill in placeholder fields (marked with `[brackets]`) with concrete details from the transcript.
- If a field already has real content, only update it if the interview provides a clear correction or meaningful addition — do not overwrite good existing content with less specific information.
- If the Company Overview toggle is entirely template placeholders, fill in everything the transcript supports and leave remaining placeholders intact for future enrichment.

**Extraction checklist for Company Overview** — actively scan the transcript for each of these. Coaches reveal this information casually in conversation (origin stories, team brags, tool complaints), not in response to direct questions. If the transcript contains any of the following and the CRM page doesn't already have it, add it:
- **Team size/composition:** How many athletes they coach, types of athletes (age group, pro, beginner), notable athlete achievements (e.g., "all 10 qualified for 70.3 Worlds"), named athletes they reference repeatedly
- **Personal athletic background:** Their own athletic history, origin story (how they got into the sport), competitive level, personal race results or milestones, prior sports experience (e.g., swam in high school, ran in college)
- **Credentials & education:** Certifications, degrees, formal nutrition training, coaching certifications, continuing education
- **Business details:** Company/brand name, location, years coaching, whether solo or part of an organization, pricing model if mentioned
- **Coaching methodology:** How they structure training blocks, their approach to nutrition periodization, how they communicate with athletes (texts, calls, TP comments), whether they prescribe detailed plans or broad guidelines
- **Tools & platforms:** Primary training platform (TP, Final Surge, etc.), wearables (Garmin, Wahoo), nutrition tools (MFP, Cronometer), and specific complaints or workarounds with those tools
- **Network & connections:** Their own coach, mentor coaches, referrals they offer, organizations they belong to, conferences they attend, podcast appearances
- **Personal details that inform rapport:** Weight loss journey, family, hobbies, personality traits (data nerd, Type A), social media presence or absence

This checklist is especially important for **repeat interviewees** — later interviews often surface background details that weren't discussed in the first conversation. Cross-reference against what's already on the CRM page and fill any gaps.

**`💡 Synthesized Insights` section:**
- **Primary Pain Point / Secondary Pain Points:** If the interview surfaces pain points that are more specific, more clearly articulated, or different from what's currently listed, update these fields. This is distinct from the Pain points *property* (6a) — the property is a flat text field, while this section allows structured detail with bullets and context. Replace placeholder text; append to existing real content.
- **Product Implications:** Add or update implications based on what the interview revealed about how this coach would use Mealvana, what features matter to them, or what gaps they see.
- **Relationship Notes:** Update with new context from the interview — how the relationship is progressing, personal details that inform rapport, engagement signals, tools/brands mentioned, credentials discovered. Append to existing notes rather than replacing them.

**Rules for CRM content updates:**
- **Fill placeholders aggressively** — if a field says `[Company Name]` or `[Certifications, years of experience]` and the transcript provides that information, fill it in.
- **Append to real content carefully** — if a section already has substantive content, add new information without disrupting what's there. Use consistent formatting.
- **Never fabricate** — only use information explicitly stated or clearly implied in the transcript. If you're unsure, leave the field as-is.
- **Don't duplicate the interview analysis** — CRM sections should contain distilled, relationship-oriented facts, not the full research narrative. The insight page (linked from 6b) has the deep analysis.
- **Update CRM properties too when relevant** — if the interview reveals a company name, phone number, email, or changes to interest level that aren't yet in the CRM properties, update those as well.

**Stop Conditions:**
- If the CRM page structure is unexpected (no recognizable sections) → Add the Interviews section at the end of the page content
- If Pain points property is very long already → Append only the most significant new pain points, not everything

---

### Step 7: Link the Transcript
After creating the insight page, the Raw Transcripts relation should already be set via the properties. Verify the link is correct.

If the raw transcript page also has an "Interview" relation property, note in the handoff that the human may want to link it back (two-way relation may auto-populate, but verify).

---

### Step 8: Update Task Queue (if applicable)
**If triggered from the AI Task Queue:**
```javascript
Status → "AI Draft Complete"
AI Notes → "Processed [Name] interview transcript into insight page. [X] key themes extracted. CRM updated. Ready for human review."
```

**If ad-hoc request:** Skip this step.

---

### Step 9: Handoff
**After creating the insight page, briefly note:**
- Link to the new insight page
- Number of key themes extracted (and any flagged as low confidence)
- Whether a CRM contact was linked (or if one needs to be created)
- What was updated on the CRM page (pain points appended, interview entry added, and which CRM sections were enriched — e.g., "Filled in Company Overview with company name, certifications, and coaching philosophy; updated Synthesized Insights with new product implications")
- Any gaps or ambiguities the human should review
- Remind human to promote Status from "Completed" → "Processed" after review
- Problem Statements were not generated per workflow scope — note if the human wants to create them separately

**Keep the handoff short** — the insight page speaks for itself.

---

## Quality Gates

**Before Creating the Page, Verify:**
- [ ] All insights are grounded in the actual transcript — no invented information, no generalized language
- [ ] Opening paragraph is dense and scannable — covers the most important findings in a few sentences
- [ ] Each theme title is a **specific insight**, not a generic category (e.g., "The 'Math Overwhelm' Moment" not "Race Day Fueling")
- [ ] Each theme includes **direct quotes** (italicized) as evidence from the transcript
- [ ] No superficial themes (e.g., "users want ease of use") unless the interviewee used those exact words
- [ ] Low-confidence themes are explicitly flagged; high-confidence themes are not annotated
- [ ] Themes selected for the database multi-select property are actually discussed in the interview
- [ ] Conditional sections (Prototype Feedback, Pilot Program) are included only when substantively present
- [ ] Interview metadata (date, duration, participants) is accurate
- [ ] Interviewee name format follows `[Name] — [number]` convention
- [ ] Relationship Notes capture engagement signals, tools/brands used, and personal context — not just content
- [ ] Content sections use specific details (numbers, product names, direct context) rather than vague summaries
- [ ] CRM Pain points were appended (not overwritten) with new interview findings
- [ ] CRM interview entry was appended under the existing `## 🎤 Interviews` section (not as a new separate section)
- [ ] CRM interview entry is a relationship-oriented summary, not a duplicate of the full analysis
- [ ] CRM Research → Company Overview placeholders were filled in with any new information from the transcript
- [ ] CRM Research → Company Overview was checked against the full extraction checklist (team size, personal athletic background, credentials, business details, coaching methodology, tools, network/connections, personal rapport details) — not just placeholder fields
- [ ] CRM Synthesized Insights section was updated with new pain points, product implications, and relationship notes where applicable
- [ ] CRM content updates use distilled, relationship-oriented facts — not duplicated research analysis
- [ ] CRM properties (Company, Number, email, Interest level) were updated if the interview revealed new or corrected values

**Flag for Human if:**
- Transcript quality is poor (lots of crosstalk, missing sections, unclear speakers)
- Interviewee discusses competitor products in ways that need strategic consideration
- Interviewee expresses frustration or negative sentiment about Mealvana
- Pricing expectations conflict with current strategy
- Interviewee is not found in CRM and may need a new entry
- Any theme flagged as "low" confidence that could significantly affect product decisions

---

## Reference Examples
- **Example Output (with demo/pilot sections):** [Lana Burl — 1](https://www.notion.so/320e3fdb754c81ab9f8efb888e9a35e1)
- **Example Output (standard):** [Claudia McCoy — 1](https://www.notion.so/305e3fdb754c81608a29c4d5230ac086)
- **Example Input:** [Claudia McCoy Interview - Raw Transcript](https://www.notion.so/306e3fdb754c81bbbbfde909667130ed)
- **Example Input:** [Lana interview](https://www.notion.so/307e3fdb754c804abfd6d6df641e4a6a)

---

## Related Resources
- **📋 Interviews Database:** [Interviews](https://www.notion.so/c06eda0cc4ed4a74bd95bdc260c29f0b)
- **📝 Raw Transcripts Database:** [Raw Transcripts](https://www.notion.so/1d559b86c68346da8b9b7b39d562ba46)
- **CRM Database:** [CRM](https://www.notion.so/2e3e3fdb754c8069bc0ece64182e22cb)
- **AI Task Queue:** [AI Task Queue](https://www.notion.so/4f40343b344446d0a99d2a212ed17527)
