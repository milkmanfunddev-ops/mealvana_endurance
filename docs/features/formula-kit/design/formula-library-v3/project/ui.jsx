// Shared UI bits — Formula Kit v2
const PHASE_TINT = {
  before: "var(--me-orange)",
  during: "var(--me-electrolyte)",
};
const PHASE_LABEL = { before: "Before", during: "During" };

// ---------- Header ----------
function FKHeader({ title, onBack, onFilters, hasMoreFilters, favoritesOnly, onToggleFavoritesOnly }) {
  return (
    <div style={{
      padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10,
    }}>
      <button onClick={onBack} aria-label="Back" style={{
        width: 40, height: 40, borderRadius: "50%",
        background: "rgba(248,246,235,0.08)",
        border: "none", cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
             stroke="var(--me-cream)" strokeWidth="2.4" strokeLinecap="square">
          <path d="M19 12H5M11 18l-6-6 6-6" />
        </svg>
      </button>
      <div style={{
        flex: 1,
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 22,
        color: "var(--me-cream)", lineHeight: 1.1,
      }}>{title}</div>
      {onToggleFavoritesOnly && (
        <button onClick={onToggleFavoritesOnly}
          aria-label={favoritesOnly ? "Showing favorites only" : "Show favorites only"}
          aria-pressed={favoritesOnly ? "true" : "false"}
          title={favoritesOnly ? "Showing favorites only" : "Show favorites only"}
          style={{
            width: 36, height: 36, borderRadius: "50%",
            background: favoritesOnly ? "var(--me-electrolyte, #3fb6c8)" : "rgba(248,246,235,0.08)",
            color: favoritesOnly ? "var(--me-blackberry)" : "var(--me-cream)",
            border: "none", cursor: "pointer",
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            flex: "0 0 auto",
            transition: "background-color 160ms, color 160ms",
          }}>
          <svg width="16" height="16" viewBox="0 0 24 24"
               fill={favoritesOnly ? "currentColor" : "none"}
               stroke="currentColor" strokeWidth="2" strokeLinejoin="miter" strokeLinecap="square">
            <path d="M12 3l2.7 6 6.3.6-4.8 4.3 1.5 6.4L12 17l-5.7 3.3L7.8 14 3 9.6 9.3 9z" />
          </svg>
        </button>
      )}
      {onFilters && (
        <button onClick={onFilters} aria-label="More filters" style={{
          height: 36, padding: "0 12px 0 10px", borderRadius: 100,
          background: hasMoreFilters ? "var(--me-orange)" : "rgba(248,246,235,0.08)",
          color: hasMoreFilters ? "var(--me-blackberry)" : "var(--me-cream)",
          border: "none", cursor: "pointer", display: "inline-flex",
          alignItems: "center", gap: 6,
          fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 12,
        }}>
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none"
               stroke="currentColor" strokeWidth="2.2" strokeLinecap="square">
            <path d="M3 6h18M6 12h12M10 18h4" />
          </svg>
          Filters
        </button>
      )}
    </div>
  );
}

// ---------- Phase tabs (only 2 now) ----------
function PhaseTabs({ value, onChange }) {
  return (
    <div style={{
      margin: "4px 17px 0",
      background: "rgba(0,0,0,0.22)",
      border: "1px solid rgba(248,246,235,0.08)",
      borderRadius: 100, padding: 4, display: "flex", gap: 2,
    }}>
      {window.PHASE_OPTS.map(opt => {
        const active = opt.id === value;
        return (
          <button key={opt.id} onClick={() => onChange(opt.id)} style={{
            flex: 1, height: 36, border: "none", borderRadius: 100, cursor: "pointer",
            background: active ? "var(--me-cream)" : "transparent",
            color: active ? "var(--me-blackberry)" : "var(--me-cream)",
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700,
            fontSize: 14,
            transition: "background-color 180ms, color 180ms",
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          }}>
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

// ---------- Filter chip (single-select pill OR multi-select checkbox) ----------
function FilterChip({ label, active, onClick, leading }) {
  return (
    <button onClick={onClick} style={{
      flex: "0 0 auto",
      height: 32, padding: leading ? "0 12px 0 10px" : "0 14px",
      borderRadius: 100,
      background: active ? "var(--me-cream)" : "transparent",
      color: active ? "var(--me-blackberry)" : "var(--me-cream)",
      border: active ? "1px solid var(--me-cream)" : "1px solid rgba(248,246,235,0.18)",
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 12.5,
      cursor: "pointer", display: "inline-flex", alignItems: "center", gap: 6,
      whiteSpace: "nowrap",
      transition: "background-color 160ms, color 160ms, border-color 160ms",
    }}>
      {leading}
      {label}
    </button>
  );
}

// ---------- Sport icon ----------
function ActivityIcon({ activity, size = 11 }) {
  const stroke = "currentColor";
  const baseProps = { width: size, height: size, viewBox: "0 0 24 24", fill: "none", stroke, strokeWidth: 2, strokeLinecap: "square", strokeLinejoin: "miter" };
  if (activity === "Running" || activity === "Triathlon — Run Leg") {
    return (<svg {...baseProps}><circle cx="14" cy="4.5" r="1.6" /><path d="M9 21l3-6 3 3 4-2M5 12l4-2 3 3M14 8l-3 3" /></svg>);
  }
  if (activity === "Cycling" || activity === "Triathlon — Bike Leg") {
    return (<svg {...baseProps}><circle cx="6" cy="17" r="3" /><circle cx="18" cy="17" r="3" /><path d="M9 17l3-7 4 4 2-3M15 6h3" /></svg>);
  }
  // Triathlon — Transition
  return (<svg {...baseProps}><path d="M4 12h6M14 12h6M10 8l4 4-4 4" /></svg>);
}

// ---------- Activity tag ----------
function ActivityTag({ activity }) {
  const labels = {
    "Running": "Running",
    "Cycling": "Cycling",
    "Triathlon — Bike Leg": "Tri — Bike",
    "Triathlon — Run Leg": "Tri — Run",
    "Triathlon — Transition": "Tri — Transition",
  };
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 5,
      height: 20, padding: "0 8px", borderRadius: 100,
      background: "rgba(248,246,235,0.08)",
      color: "rgba(248,246,235,0.85)",
      fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
    }}>
      <ActivityIcon activity={activity} size={10} />
      {labels[activity] || activity}
    </span>
  );
}

// ---------- Generic info pill ----------
function InfoPill({ label, tone = "default" }) {
  const styles = {
    default:    { bg: "rgba(248,246,235,0.08)", color: "rgba(248,246,235,0.85)" },
    accent:     { bg: "rgba(247,139,20,0.15)", color: "var(--me-orange-light)" },
    success:    { bg: "rgba(28,249,207,0.12)", color: "var(--me-electrolyte)" },
    mono:       { bg: "rgba(248,246,235,0.08)", color: "rgba(248,246,235,0.85)", mono: true },
  };
  const s = styles[tone] || styles.default;
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", height: 20, padding: "0 8px",
      borderRadius: 100, background: s.bg, color: s.color,
      fontFamily: s.mono ? "'Apercu Mono', monospace" : "Apercu, sans-serif",
      fontWeight: 500, fontSize: 10.5,
      fontVariantNumeric: s.mono ? "tabular-nums" : "normal",
    }}>{label}</span>
  );
}

// ---------- Allergen / exclude tags ----------
function AllergenTag({ label }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 4,
      height: 19, padding: "0 7px", borderRadius: 4,
      background: "rgba(220,37,151,0.14)",
      color: "var(--me-dragonfruit)",
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 10,
      letterSpacing: "0.04em",
    }}>
      <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="square">
        <path d="M12 4v9M12 17v2" />
      </svg>
      {label}
    </span>
  );
}
function ExcludeTag({ label }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center",
      height: 19, padding: "0 7px", borderRadius: 4,
      background: "rgba(248,246,235,0.06)",
      color: "rgba(248,246,235,0.5)",
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 10,
      textDecoration: "line-through",
      textDecorationColor: "rgba(248,246,235,0.4)",
    }}>{label}</span>
  );
}

// ---------- Dietary banner ----------
function DietaryBanner({ diet, allergens, ignored, onToggle }) {
  if (diet.length === 0 && allergens.length === 0) return null;
  const labels = [
    ...diet.map(d => window.DIET_LABELS[d] || d),
    ...allergens.map(a => `no ${a.toLowerCase()}`),
  ];
  return (
    <div style={{
      margin: "10px 17px 0",
      padding: "10px 14px", borderRadius: 12,
      background: ignored ? "rgba(248,246,235,0.04)" : "rgba(247,139,20,0.10)",
      border: `1px solid ${ignored ? "rgba(248,246,235,0.1)" : "rgba(247,139,20,0.3)"}`,
      display: "flex", alignItems: "center", gap: 10,
    }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
           stroke={ignored ? "rgba(248,246,235,0.4)" : "var(--me-orange)"} strokeWidth="2" strokeLinecap="square">
        {ignored
          ? <><circle cx="12" cy="12" r="9" /><path d="M9 9l6 6M15 9l-6 6" /></>
          : <><path d="M3 7l9-4 9 4-9 4-9-4z" /><path d="M3 12l9 4 9-4M3 17l9 4 9-4" /></>}
      </svg>
      <div style={{
        flex: 1, fontFamily: "Apercu, sans-serif", fontSize: 12, lineHeight: 1.4,
        color: ignored ? "rgba(248,246,235,0.55)" : "var(--me-cream)",
      }}>
        {ignored ? (
          <>Showing all templates — your dietary profile is paused.</>
        ) : (
          <>Filtered for <span style={{ fontWeight: 500, color: "var(--me-cream)" }}>{labels.join(", ")}</span></>
        )}
      </div>
      <button onClick={onToggle} style={{
        background: "transparent", border: "none",
        color: "var(--me-orange)",
        fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
        cursor: "pointer", padding: 0, whiteSpace: "nowrap",
      }}>{ignored ? "Apply profile" : "Show all"}</button>
    </div>
  );
}

// ---------- Macro row (Before only) ----------
function MacroRow({ macros }) {
  const items = [
    { label: "Carbs",  value: macros.carbs,   unit: "g",  color: "var(--me-carbs)" },
    { label: "Protein",value: macros.protein, unit: "g",  color: "var(--me-dragonfruit)" },
    { label: "Fat",    value: macros.fat,     unit: "g",  color: "oklch(0.74 0.15 60)" },
    { label: "Sodium", value: macros.sodium,  unit: "mg", color: "var(--me-electrolyte)" },
    { label: "Fluid",  value: macros.fluid,   unit: "ml", color: "oklch(0.65 0.13 240)" },
  ];
  return (
    <div style={{
      display: "grid", gridTemplateColumns: "repeat(5, 1fr)",
      gap: 6, padding: "10px 0",
      borderTop: "1px solid rgba(248,246,235,0.08)",
      borderBottom: "1px solid rgba(248,246,235,0.08)",
    }}>
      {items.map(it => (
        <div key={it.label} style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}>
          <div style={{
            fontFamily: "'Apercu Mono', monospace", fontSize: 13, fontWeight: 500,
            color: "var(--me-cream)", fontVariantNumeric: "tabular-nums", lineHeight: 1,
          }}>{it.value}<span style={{ fontSize: 10, color: "rgba(248,246,235,0.5)" }}>{it.unit}</span></div>
          <div style={{
            display: "flex", alignItems: "center", gap: 4,
            fontFamily: "Apercu, sans-serif", fontSize: 9, fontWeight: 500,
            letterSpacing: "0.06em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.55)",
          }}>
            <span style={{ width: 4, height: 4, borderRadius: "50%", background: it.color }} />
            {it.label}
          </div>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, {
  FKHeader, PhaseTabs, FilterChip,
  ActivityIcon, ActivityTag, InfoPill,
  AllergenTag, ExcludeTag, DietaryBanner, MacroRow,
  PHASE_TINT, PHASE_LABEL,
  FavoriteStar,
});

// ---------- Favorite star ----------
// 44\u00d744 hit target with an ~18px star icon. Outlined at ~40% opacity when
// inactive; filled teal when active. Tapping triggers a 150ms 1\u21921.2\u21921 pulse
// by re-keying the icon so the CSS animation re-runs.
function FavoriteStar({ active, onClick }) {
  const tickRef = React.useRef(0);
  const [tick, setTick] = React.useState(0);
  const handleClick = (e) => {
    e.stopPropagation();
    tickRef.current += 1;
    setTick(tickRef.current);
    onClick && onClick();
  };
  return (
    <button
      onClick={handleClick}
      aria-label={active ? "Remove favorite" : "Add favorite"}
      style={{
        width: 44, height: 44, padding: 0,
        background: "transparent", border: "none",
        borderRadius: 22, cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}
    >
      <svg
        key={tick}
        width="20" height="20" viewBox="0 0 24 24"
        fill={active ? "var(--me-electrolyte)" : "none"}
        stroke={active ? "var(--me-electrolyte)" : "var(--me-cream)"}
        strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round"
        style={{
          opacity: active ? 1 : 0.4,
          animation: tick > 0 ? "fk-star-pulse 150ms ease-out" : undefined,
          transition: "opacity 160ms ease",
        }}
      >
        <path d="M12 2.6l2.94 5.96 6.58.96-4.76 4.64 1.12 6.55L12 17.62l-5.88 3.09 1.12-6.55L2.48 9.52l6.58-.96L12 2.6z" />
      </svg>
    </button>
  );
}
