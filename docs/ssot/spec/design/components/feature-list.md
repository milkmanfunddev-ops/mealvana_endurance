# Design SSOT — Component: Feature List

**Status: PROPOSED v1 (Lee, 2026-09-21) — authored app-side, awaiting Xuan.** Written from paywall
ticket 14 (decisions mp-493 §2 and §6, mp-497 §4, approved as mp-498). No reference rendering yet.

**Component contract** — what a plan buys, as a list a person scrolls: a few headline features, an
"also includes" divider, and the rest. It owns the two tiers, the divider and the marks. It never
owns the words (the content system does) or which features count as AI (the caller groups them).

**Tokens / material:** [`../tokens.md`](../tokens.md) — ink and secondary ink for the words,
electrolyte for the icons. §Materials: an ordinary feature's mark is an icon in a `glass` disc;
the rows themselves sit on the page's ground with no fill and no border (not a content card).

## Contracts

- **FL-1 — two tiers.** Headline rows carry a title and one line of body. The rows after the
  divider are title only, with tighter spacing and smaller marks. The divider (hairline, label,
  hairline; the label in overline) sits between the tiers, and only when there are rows after it.
- **FL-2 — marks.** Each row leads with its mark: an icon in a glass disc, or, for the Vana line,
  the one Vana avatar. On the paywall the AI features (meal planning, answers, photo and text meal
  logging) share that one Vana line, so a lapsed athlete reads one reason, not four refusals
  (mp-493 §2).
- **FL-3 — words from the caller.** Every title, body and the divider label come from the caller.
- **FL-4 — one sentence per row.** A screen reader reads each row as its title and body together;
  the mark is excluded.

## Implementation

`lib/shared/widgets/kyle_design/cards/feature_list.dart` — `FeatureList`, `FeatureListItem`,
`FeatureListIcon`.

## Open questions for Xuan

- **Q-FL1** — electrolyte icons on the cream ground are low contrast, and the glass disc barely
  shows there (the glass light variant is deferred). The paywall's intro line already uses
  electrolyte on cream, so v1 follows it.
