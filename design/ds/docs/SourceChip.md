---
category: Data
---
# SourceChip

D-2 source-provenance chip family (RATIFIED Xuan 2026-09-11; Q-DID2 variant A — **source only**, no relative time; manual-wins; inline conflict, **never a modal**). One parameterized family shared by FTP/CSS, body composition, events, and onboarding pre-fill.

- `SourceChip` — one pill. `Manual` renders cream; every provider renders electrolyte. `value` is shown only in a conflict pairing.
- `TapToUseChip` — the conflict adopt affordance, in the same pill outline (electrolyte). A single tap adopts the provider value; never a modal.
- `StaleChip` — the small "stale" tag, shown only past the surface's window and only with a provider value.
- `SourceProvenanceRow` — the composed row: agreement/provider-only → one source pill; a real conflict → Manual pill + tap-to-use pill; plus the stale tag when applicable.

```tsx
<SourceProvenanceRow manualValue={250} providerValue={240} unit="W" onAdoptProvider={(v) => setFtp(v)} />
<SourceProvenanceRow manualValue={154} providerValue={152} providerName="Garmin" unit="lb" onAdoptProvider={adopt} />
<SourceChip source="Final Surge" />
```

**Dart source (promote from):** `lib/shared/widgets/kyle_design/data/kyle_source_chip.dart` (spec: `docs/ssot/spec/design/surfaces/integrations-data-display.md` D-2; rendering: `renderings/ftp-source-provenance@v1.html`)
