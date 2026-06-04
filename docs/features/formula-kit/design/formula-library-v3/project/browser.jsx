// Browser screen — Before sections + During filter rows
const { useState: useStateB, useMemo: useMemoB, useRef: useRefB, useEffect: useEffectB } = React;

function BrowserScreen({
  phase, setPhase,
  diet, allergens, ignoreDiet, setIgnoreDiet,
  beforeSubPhase, setBeforeSubPhase,
  duringActivity, setDuringActivity,
  duringDuration, setDuringDuration,
  moreOpen, setMoreOpen,
  beforeMore, duringMore,
  collapsed, setCollapsed,
  personalFormulas, customFoods,
  favorites, isFavorite, toggleFavorite, favoritesOnly, setFavoritesOnly,
  onOpenFormula, onOpenPersonal, onOpenCreate, highlightId,
}) {
  const onFilters = () => setMoreOpen(true);
  const dietCount = (ignoreDiet ? 0 : (diet.length + allergens.length));
  const moreFilterCount = dietCount
    + (favoritesOnly ? 1 : 0)
    + (phase === "before"
      ? (beforeMore.digestion ? 1 : 0)
      : duringMore.foodForms.length + (duringMore.gut ? 1 : 0));

  // Header collapse — driven by list scroll
  const [headerCollapsed, setHeaderCollapsed] = useStateB(false);
  const onListScroll = (e) => {
    const top = e.target.scrollTop;
    if (top > 24 && !headerCollapsed) setHeaderCollapsed(true);
    else if (top < 8 && headerCollapsed) setHeaderCollapsed(false);
  };
  // Reset collapse when phase changes
  useEffectB(() => { setHeaderCollapsed(false); }, [phase]);

  const phaseFilterCount = phase === "before"
    ? (beforeSubPhase ? 1 : 0)
    : (duringActivity ? 1 : 0) + (duringDuration ? 1 : 0);

  return (
    <div style={{
      flex: 1, display: "flex", flexDirection: "column",
      background: "var(--me-blackberry)", color: "var(--me-cream)", overflow: "hidden",
      position: "relative",
    }}>
      <FKHeader
        title="Formula Kit"
        onBack={() => {}}
        onFilters={onFilters}
        hasMoreFilters={moreFilterCount > 0}
        favoritesOnly={favoritesOnly}
        onToggleFavoritesOnly={() => setFavoritesOnly && setFavoritesOnly(!favoritesOnly)}
      />

      <CollapsibleHeader collapsed={headerCollapsed}>
        <div style={{
          padding: "0 17px 10px",
          fontFamily: "Apercu, sans-serif", fontSize: 12.5, lineHeight: 1.45,
          color: "rgba(248,246,235,0.6)",
        }}>
          Browse system templates by phase. The kit is filtered to your dietary profile.
        </div>
        <PhaseTabs value={phase} onChange={setPhase} />
      </CollapsibleHeader>

      {phase === "before" ? (
        <BeforeBody
          diet={diet} allergens={allergens} ignoreDiet={ignoreDiet}
          beforeSubPhase={beforeSubPhase} setBeforeSubPhase={setBeforeSubPhase}
          beforeMore={beforeMore}
          personalFormulas={personalFormulas} customFoods={customFoods}
          favorites={favorites} isFavorite={isFavorite} toggleFavorite={toggleFavorite}
          favoritesOnly={favoritesOnly}
          onOpenFormula={onOpenFormula} onOpenPersonal={onOpenPersonal}
          onOpenCreate={onOpenCreate} highlightId={highlightId}
          setIgnoreDiet={setIgnoreDiet}
          headerCollapsed={headerCollapsed}
          setHeaderCollapsed={setHeaderCollapsed}
          onListScroll={onListScroll}
          phaseFilterCount={phaseFilterCount}
        />
      ) : (
        <DuringBody
          diet={diet} allergens={allergens} ignoreDiet={ignoreDiet}
          duringActivity={duringActivity} setDuringActivity={setDuringActivity}
          duringDuration={duringDuration} setDuringDuration={setDuringDuration}
          duringMore={duringMore}
          personalFormulas={personalFormulas} customFoods={customFoods}
          favorites={favorites} isFavorite={isFavorite} toggleFavorite={toggleFavorite}
          favoritesOnly={favoritesOnly}
          onOpenFormula={onOpenFormula} onOpenPersonal={onOpenPersonal}
          onOpenCreate={onOpenCreate} highlightId={highlightId}
          setIgnoreDiet={setIgnoreDiet}
          headerCollapsed={headerCollapsed}
          setHeaderCollapsed={setHeaderCollapsed}
          onListScroll={onListScroll}
          phaseFilterCount={phaseFilterCount}
        />
      )}
    </div>
  );
}

// Collapsible wrapper — animates height + opacity when `collapsed`
function CollapsibleHeader({ collapsed, children }) {
  const inner = useRefB(null);
  const [h, setH] = useStateB("auto");
  useEffectB(() => {
    if (!inner.current) return;
    setH(inner.current.scrollHeight);
  }, [children]);
  return (
    <div style={{
      maxHeight: collapsed ? 0 : (h === "auto" ? "none" : h),
      opacity: collapsed ? 0 : 1,
      overflow: "hidden",
      transition: "max-height 240ms cubic-bezier(0.2,0.8,0.2,1), opacity 180ms ease",
      pointerEvents: collapsed ? "none" : "auto",
    }}>
      <div ref={inner}>{children}</div>
    </div>
  );
}

// Compact sticky strip shown in collapsed state
function CollapsedStrip({ phase, activeFilters, count, total, onExpand }) {
  return (
    <button onClick={onExpand} style={{
      width: "100%", border: "none", cursor: "pointer",
      background: "rgba(248,246,235,0.04)",
      borderTop: "1px solid rgba(248,246,235,0.06)",
      borderBottom: "1px solid rgba(248,246,235,0.08)",
      padding: "10px 17px",
      display: "flex", alignItems: "center", gap: 8,
      color: "var(--me-cream)",
      flexWrap: "wrap",
    }}>
      <div style={{
        display: "inline-flex", alignItems: "center", gap: 6,
        height: 26, padding: "0 12px", borderRadius: 100,
        background: "var(--me-cream)", color: "var(--me-blackberry)",
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 12,
        flex: "0 0 auto",
      }}>
        {phase === "before" ? "Before" : "During"}
      </div>
      {(activeFilters || []).map((f, i) => (
        <span key={i} style={{
          display: "inline-flex", alignItems: "center",
          height: 24, padding: "0 10px", borderRadius: 100,
          background: "var(--me-orange)", color: "var(--me-blackberry)",
          fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 11,
          flex: "0 0 auto",
        }}>{f}</span>
      ))}
      <div style={{
        fontFamily: "Apercu, sans-serif", fontSize: 11, fontWeight: 500,
        letterSpacing: "0.06em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.55)",
        flex: "0 0 auto",
      }}>
        {count}/{total}
      </div>
      <div style={{ flex: 1 }} />
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none"
           stroke="rgba(248,246,235,0.55)" strokeWidth="2.2" strokeLinecap="square" style={{ flex: "0 0 auto" }}>
        <path d="M6 15l6-6 6 6" />
      </svg>
    </button>
  );
}

// ---------- BEFORE ----------
function BeforeBody({ diet, allergens, ignoreDiet, beforeSubPhase, setBeforeSubPhase, beforeMore, personalFormulas, customFoods, favorites, isFavorite, toggleFavorite, favoritesOnly, onOpenFormula, onOpenPersonal, onOpenCreate, highlightId, setIgnoreDiet, headerCollapsed, setHeaderCollapsed, onListScroll, phaseFilterCount }) {
  const filtered = useMemoB(() => {
    let list = window.BEFORE_FORMULAS;
    if (!ignoreDiet) list = list.filter(f => passesDiet(f, diet, allergens));
    if (beforeSubPhase) list = list.filter(f => f.sub_phase === beforeSubPhase);
    if (beforeMore.digestion) list = list.filter(f => f.digestion === beforeMore.digestion);
    if (beforeMore.types.length) list = list.filter(f => beforeMore.types.includes(f.type));
    if (favoritesOnly) list = list.filter(f => isFavorite("system", f.id));
    return list;
  }, [diet, allergens, ignoreDiet, beforeSubPhase, beforeMore, favoritesOnly, favorites]);

  // Apply the same phase + dietary + more-filter logic to personal Before formulas,
  // so the "Your formulas" section narrows in lockstep with the system list. Favorites-only
  // is intentionally NOT applied here — YourFormulasSection handles it (and hides itself
  // entirely when the user has no favorited personals).
  const filteredPersonals = useMemoB(() => {
    let list = (personalFormulas || []).filter(p => p.sourcePhase === "before");
    if (!ignoreDiet) list = list.filter(p => passesDiet(p, diet, allergens));
    if (beforeSubPhase) list = list.filter(p => p.sub_phase === beforeSubPhase);
    if (beforeMore.digestion) list = list.filter(p => p.digestion === beforeMore.digestion);
    if (beforeMore.types.length) list = list.filter(p => beforeMore.types.includes(p.type));
    return list;
  }, [personalFormulas, diet, allergens, ignoreDiet, beforeSubPhase, beforeMore]);

  const clearAll = () => setBeforeSubPhase(null);
  const filterCount = beforeSubPhase ? 1 : 0;

  return (
    <>
      <CollapsibleHeader collapsed={headerCollapsed}>
        <div style={{ padding: "12px 0 8px", borderBottom: "1px solid rgba(248,246,235,0.06)" }}>
          <ChipScrollRow label="Timing">
            {window.SUB_PHASE_OPTS.map(sp => (
              <FilterChip key={sp.id} label={sp.label}
                active={beforeSubPhase === sp.id}
                onClick={() => setBeforeSubPhase(beforeSubPhase === sp.id ? null : sp.id)}
              />
            ))}
          </ChipScrollRow>
        </div>

        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "12px 17px 8px",
        }}>
          <div style={{
            fontFamily: "Apercu, sans-serif", fontSize: 11, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.55)",
          }}>
            {filtered.length} of {window.BEFORE_FORMULAS.length} templates
            {beforeSubPhase && <> · {window.SUB_PHASE_OPTS.find(s => s.id === beforeSubPhase)?.sub}</>}
          </div>
          {filterCount > 0 && (
            <button onClick={clearAll} style={{
              background: "transparent", border: "none", color: "var(--me-orange)",
              fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
              cursor: "pointer", padding: 0,
            }}>Clear filters</button>
          )}
        </div>
      </CollapsibleHeader>

      {headerCollapsed && (
        <CollapsedStrip
          phase="before"
          activeFilters={beforeSubPhase ? [window.SUB_PHASE_OPTS.find(s => s.id === beforeSubPhase)?.label].filter(Boolean) : []}
          count={filtered.length} total={window.BEFORE_FORMULAS.length}
          onExpand={() => setHeaderCollapsed(false)}
        />
      )}

      <div onScroll={onListScroll} style={{ flex: 1, overflow: "auto", padding: "12px 17px 100px" }}>
        <YourFormulasSection
          phase="before"
          personalFormulas={filteredPersonals}
          totalPersonals={(personalFormulas || []).filter(p => p.sourcePhase === "before").length}
          customFoods={customFoods}
          isFavorite={isFavorite} toggleFavorite={toggleFavorite}
          favoritesOnly={favoritesOnly}
          onOpen={onOpenPersonal}
          onCreate={() => onOpenCreate && onOpenCreate("before")}
          highlightId={highlightId}
        />
        {filtered.length === 0 ? (
          <DuringEmptyState
            duringActivity={null}
            duringDuration={null}
            ignoreDiet={ignoreDiet}
            onClear={clearAll}
            onShowAll={() => setIgnoreDiet(true)}
          />
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {filtered.map(f => (
              <BeforeCard key={f.id} formula={f}
                isFavorite={isFavorite("system", f.id)}
                onToggleFavorite={() => toggleFavorite("system", f.id)}
                onClick={() => onOpenFormula(f)} />
            ))}
          </div>
        )}
      </div>
    </>
  );
}

function BeforeSection({ group, collapsed, onToggle, onOpenFormula, onShowAll }) {
  return (
    <div>
      <button onClick={onToggle} style={{
        width: "100%", display: "flex", alignItems: "center", gap: 10,
        background: "transparent", border: "none", cursor: "pointer",
        padding: "4px 0 10px", textAlign: "left",
      }}>
        <div style={{
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 18,
          color: "var(--me-cream)", lineHeight: 1.1,
        }}>{group.label}</div>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 11.5,
          color: "rgba(248,246,235,0.5)",
        }}>{group.sub}</div>
        <div style={{ flex: 1 }} />
        <div style={{
          fontFamily: "'Apercu Mono', monospace", fontSize: 11,
          color: "rgba(248,246,235,0.55)",
        }}>{group.items.length}</div>
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none"
             stroke="rgba(248,246,235,0.55)" strokeWidth="2.4" strokeLinecap="square"
             style={{ transform: collapsed ? "rotate(-90deg)" : "rotate(0deg)", transition: "transform 180ms" }}>
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {!collapsed && (
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {group.items.length === 0 ? (
            <div style={{
              padding: "14px 14px", borderRadius: 12,
              background: "rgba(248,246,235,0.03)",
              border: "1px dashed rgba(248,246,235,0.12)",
              display: "flex", alignItems: "center", gap: 10,
              fontFamily: "Apercu, sans-serif", fontSize: 12,
              color: "rgba(248,246,235,0.6)",
            }}>
              <span style={{ flex: 1 }}>No {group.label.toLowerCase()} templates match your dietary profile.</span>
              <button onClick={onShowAll} style={{
                background: "transparent", border: "none", color: "var(--me-orange)",
                fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
                cursor: "pointer", padding: 0,
              }}>Show all</button>
            </div>
          ) : (
            group.items.map(f => <BeforeCard key={f.id} formula={f} onClick={() => onOpenFormula(f)} />)
          )}
        </div>
      )}
    </div>
  );
}

function BeforeCard({ formula, onClick, isFavorite, onToggleFavorite }) {
  return (
    <div onClick={onClick} role="button" tabIndex={0}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick && onClick(); } }}
      style={{
        position: "relative",
        width: "100%", textAlign: "left", cursor: "pointer",
        background: "rgba(248,246,235,0.04)",
        border: "1px solid rgba(248,246,235,0.08)",
        borderRadius: 15, padding: "12px 14px",
        display: "flex", flexDirection: "column", gap: 8,
        boxSizing: "border-box",
      }}>
      {/* Name (right-padded to clear the star) */}
      <div style={{ display: "flex", alignItems: "flex-start", gap: 10, paddingRight: 44 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 17,
            color: "var(--me-cream)", lineHeight: 1.15,
          }}>{formula.name}</div>
        </div>
      </div>

      {/* Favorite star — absolutely positioned top-right; replaces the chevron */}
      <div style={{ position: "absolute", top: 4, right: 4 }}>
        <window.FavoriteStar active={isFavorite} onClick={onToggleFavorite} />
      </div>

      {/* Components list */}
      <div style={{
        fontFamily: "Compadre, Georgia, serif", fontSize: 13, lineHeight: 1.3,
        color: "rgba(248,246,235,0.7)",
      }}>
        {formula.components.join("  ·  ")}
      </div>

      {/* Compact macros */}
      <CompactMacros macros={formula.macros} />
    </div>
  );
}

function CompactMacros({ macros }) {
  const items = [
    { value: macros.carbs, unit: "g", color: "var(--me-carbs)" },
    { value: macros.protein, unit: "g", color: "var(--me-dragonfruit)" },
    { value: macros.sodium, unit: "mg", color: "var(--me-electrolyte)" },
  ].filter(i => i.value != null);
  return (
    <div style={{
      display: "flex", gap: 10,
      fontFamily: "'Apercu Mono', monospace", fontSize: 10.5,
      color: "rgba(248,246,235,0.7)", fontVariantNumeric: "tabular-nums",
    }}>
      {items.map((it, i) => (
        <span key={i} style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
          <span style={{ width: 5, height: 5, borderRadius: "50%", background: it.color }} />
          {it.value}{it.unit}
        </span>
      ))}
    </div>
  );
}

function typeLabel(t) {
  return t === "food" ? "Food" : t === "drink" ? "Drink" : "Electrolyte";
}

// ---------- DURING ----------
function DuringBody({ diet, allergens, ignoreDiet, duringActivity, setDuringActivity, duringDuration, setDuringDuration, duringMore, personalFormulas, customFoods, favorites, isFavorite, toggleFavorite, favoritesOnly, onOpenFormula, onOpenPersonal, onOpenCreate, highlightId, setIgnoreDiet, headerCollapsed, setHeaderCollapsed, onListScroll, phaseFilterCount }) {
  const filtered = useMemoB(() => {
    let list = window.DURING_FORMULAS;
    if (!ignoreDiet) list = list.filter(f => passesDiet(f, diet, allergens));
    if (duringActivity) list = list.filter(f => f.activities.includes(duringActivity));
    if (duringDuration) list = list.filter(f => f.durations.includes(duringDuration));
    if (duringMore.foodForms.length) list = list.filter(f => duringMore.foodForms.includes(f.foodForm));
    if (duringMore.gut) list = list.filter(f => f.gut.includes(duringMore.gut));
    if (favoritesOnly) list = list.filter(f => isFavorite("system", f.id));
    return list;
  }, [diet, allergens, ignoreDiet, duringActivity, duringDuration, duringMore, favoritesOnly, favorites]);

  // Mirror the system-formula filter on personal During formulas. Favorites-only is
  // intentionally NOT applied here — YourFormulasSection handles favorites filtering
  // (and hides the whole section if nothing matches).
  const filteredPersonals = useMemoB(() => {
    let list = (personalFormulas || []).filter(p => p.sourcePhase === "during");
    if (!ignoreDiet) list = list.filter(p => passesDiet(p, diet, allergens));
    if (duringActivity) list = list.filter(p => (p.activities || []).includes(duringActivity));
    if (duringDuration) list = list.filter(p => (p.durations || []).includes(duringDuration));
    if (duringMore.foodForms.length) list = list.filter(p => duringMore.foodForms.includes(p.foodForm));
    if (duringMore.gut) list = list.filter(p => (p.gut || []).includes(duringMore.gut));
    return list;
  }, [personalFormulas, diet, allergens, ignoreDiet, duringActivity, duringDuration, duringMore]);

  const clearAll = () => { setDuringActivity(null); setDuringDuration(null); };
  const filterCount = (duringActivity ? 1 : 0) + (duringDuration ? 1 : 0);

  return (
    <>
      <CollapsibleHeader collapsed={headerCollapsed}>
        <div style={{ padding: "12px 0 8px", borderBottom: "1px solid rgba(248,246,235,0.06)" }}>
          <ChipScrollRow label="Activity">
            {window.ACTIVITY_OPTS.map(a => (
              <FilterChip key={a.id} label={a.label}
                active={duringActivity === a.id}
                onClick={() => setDuringActivity(duringActivity === a.id ? null : a.id)}
                leading={<ActivityIcon activity={a.id} size={11} />}
              />
            ))}
          </ChipScrollRow>
          <ChipScrollRow label="Duration">
            {window.DURING_DURATION_OPTS.map(d => (
              <FilterChip key={d.id} label={d.label}
                active={duringDuration === d.id}
                onClick={() => setDuringDuration(duringDuration === d.id ? null : d.id)}
              />
            ))}
          </ChipScrollRow>
        </div>

        <div style={{
          display: "flex", alignItems: "center", justifyContent: "space-between",
          padding: "12px 17px 8px",
        }}>
          <div style={{
            fontFamily: "Apercu, sans-serif", fontSize: 11, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.55)",
          }}>{filtered.length} of {window.DURING_FORMULAS.length} templates</div>
          {filterCount > 0 && (
            <button onClick={clearAll} style={{
              background: "transparent", border: "none", color: "var(--me-orange)",
              fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
              cursor: "pointer", padding: 0,
            }}>Clear filters</button>
          )}
        </div>
      </CollapsibleHeader>

      {headerCollapsed && (
        <CollapsedStrip
          phase="during"
          activeFilters={[
            duringActivity && window.ACTIVITY_OPTS.find(a => a.id === duringActivity)?.label,
            duringDuration && window.DURING_DURATION_OPTS.find(d => d.id === duringDuration)?.label,
          ].filter(Boolean)}
          count={filtered.length} total={window.DURING_FORMULAS.length}
          onExpand={() => setHeaderCollapsed(false)}
        />
      )}

      <div onScroll={onListScroll} style={{ flex: 1, overflow: "auto", padding: "12px 17px 100px" }}>
        <YourFormulasSection
          phase="during"
          personalFormulas={filteredPersonals}
          totalPersonals={(personalFormulas || []).filter(p => p.sourcePhase === "during").length}
          customFoods={customFoods}
          isFavorite={isFavorite} toggleFavorite={toggleFavorite}
          favoritesOnly={favoritesOnly}
          onOpen={onOpenPersonal}
          onCreate={() => onOpenCreate && onOpenCreate("during")}
          highlightId={highlightId}
        />
        {filtered.length === 0 ? (
          <DuringEmptyState
            duringActivity={duringActivity}
            duringDuration={duringDuration}
            ignoreDiet={ignoreDiet}
            onClear={clearAll}
            onShowAll={() => setIgnoreDiet(true)}
          />
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {filtered.map(f => (
              <DuringCard key={f.id} formula={f}
                isFavorite={isFavorite("system", f.id)}
                onToggleFavorite={() => toggleFavorite("system", f.id)}
                onClick={() => onOpenFormula(f)} />
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// One short descriptor per during template, replacing the old eyebrow /
// components / mono formula / food-form badge stack. Falls back to the
// formula string for any id not listed.
const DURING_DESCRIPTORS = {
  "d-tri-transition":    "Fast carbs between disciplines",
  "d-gel-water":         "Beginner-friendly, easy on gut",
  "d-gel-sd":            "Stretch gels into longer sessions",
  "d-gel-sd-water":      "Stretch gels into longer sessions",
  "d-chews-water":       "If gels feel too sweet or sticky",
  "d-chews-sd":          "Chew alternative that stretches further",
  "d-sd-only":           "Under 90 min — keep it simple",
  "d-hcdm-water":        "Max carbs without chewing — trained gut",
  "d-bar-sd-water":      "Solid food, mid-distance, any stomach",
  "d-stroopwafel":       "Cyclist's classic — easy to eat mid-ride",
  "d-banana-sd-water":   "Real food, gentle on stomach",
  "d-banana-gelwater-sd":"Long-ride variety with whole food",
  "d-rice-cake-sd":      "Real-food cycling staple, any duration",
  "d-banana-water":      "Whole-food simplicity, short rides",
  "d-dates-sd":          "Natural sugar, easy chew",
  "d-pbj-water":         "Substantial fueling for ultras",
  "d-water-tab":         "Hydration-first for short efforts",
  "d-2gel-sd":           "Double gels for high-output hours",
  "d-real-food-mix":     "Sweet + savory ultra fuel",
  "d-hcdm-water-tab":    "All-liquid carbs for big ultra days",
  "d-honey-water":       "Single-ingredient natural gel",
  "d-banana-honey-water":"Whole-food + natural sugar combo",
  "d-bonk-bar":          "Real-food bar, long endurance",
  "d-juice-water":       "Sweet & simple under 90 min",
  "d-sd-tab-water":      "Electrolyte-heavy hot-weather option",
};

function DuringCard({ formula, onClick, isFavorite, onToggleFavorite }) {
  const descriptor = DURING_DESCRIPTORS[formula.id] || formula.formula;
  return (
    <div onClick={onClick} role="button" tabIndex={0}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick && onClick(); } }}
      style={{
        position: "relative",
        width: "100%", textAlign: "left", cursor: "pointer",
        background: "rgba(248,246,235,0.04)",
        border: "1px solid rgba(248,246,235,0.08)",
        borderRadius: 15, padding: "12px 14px",
        display: "flex", flexDirection: "column", gap: 6,
        boxSizing: "border-box",
      }}>
      {/* Name */}
      <div style={{ paddingRight: 44 }}>
        <div style={{
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 17,
          color: "var(--me-cream)", lineHeight: 1.2,
        }}>{formula.name}</div>
      </div>

      {/* Favorite star — absolutely positioned top-right; replaces the chevron */}
      <div style={{ position: "absolute", top: 4, right: 4 }}>
        <window.FavoriteStar active={isFavorite} onClick={onToggleFavorite} />
      </div>

      {/* Single descriptor — replaces eyebrow / components / mono subtitle / badge */}
      <div style={{
        fontFamily: "Compadre, Georgia, serif", fontSize: 13, lineHeight: 1.3,
        color: "rgba(248,246,235,0.7)",
      }}>
        {descriptor}
      </div>
    </div>
  );
}

function ChipGroup({ label, items, mono }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
      <span style={{
        fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 9,
        letterSpacing: "0.08em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.45)",
      }}>{label}</span>
      {items.map((it, i) => (
        <span key={i} style={{
          display: "inline-flex", alignItems: "center",
          height: 18, padding: "0 7px", borderRadius: 4,
          background: "rgba(248,246,235,0.08)",
          color: "rgba(248,246,235,0.85)",
          fontFamily: mono ? "'Apercu Mono', monospace" : "Apercu, sans-serif",
          fontSize: 10.5, fontWeight: 500,
          fontVariantNumeric: mono ? "tabular-nums" : "normal",
        }}>{it}</span>
      ))}
    </div>
  );
}

function durationLabel(d) {
  const map = { "<90": "< 90 min", "90-150": "90–150 min", "150-240": "150–240 min", ">240": "> 240 min" };
  return map[d] || d;
}

function DuringEmptyState({ duringActivity, duringDuration, ignoreDiet, onClear, onShowAll }) {
  const labels = [];
  if (duringActivity) labels.push(duringActivity);
  if (duringDuration) labels.push(durationLabel(duringDuration));
  return (
    <div style={{
      marginTop: 28, padding: "28px 20px",
      background: "rgba(248,246,235,0.03)",
      border: "1px dashed rgba(248,246,235,0.15)",
      borderRadius: 15,
      display: "flex", flexDirection: "column", alignItems: "center", gap: 12, textAlign: "center",
    }}>
      <div style={{
        width: 48, height: 48, borderRadius: "50%",
        background: "rgba(247,139,20,0.12)",
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--me-orange)" strokeWidth="2" strokeLinecap="square">
          <circle cx="11" cy="11" r="7" /><path d="M21 21l-4.35-4.35" />
        </svg>
      </div>
      <div style={{ fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 17, color: "var(--me-cream)" }}>
        No templates match
      </div>
      <div style={{ fontFamily: "Apercu, sans-serif", fontSize: 12.5, color: "rgba(248,246,235,0.65)", maxWidth: 250, lineHeight: 1.5 }}>
        {labels.length > 0 ? <>Active filters: <span style={{ color: "var(--me-cream)" }}>{labels.join(" · ")}</span></> : "Try adjusting your filters."}
        {!ignoreDiet && <> Your dietary profile is also active.</>}
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        {(duringActivity || duringDuration) && (
          <button onClick={onClear} style={{
            background: "transparent", border: "1px solid var(--me-orange)",
            color: "var(--me-cream)", borderRadius: 100, padding: "8px 16px",
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 12, cursor: "pointer",
          }}>Clear filters</button>
        )}
        {!ignoreDiet && (
          <button onClick={onShowAll} style={{
            background: "transparent", border: "1px solid rgba(248,246,235,0.25)",
            color: "var(--me-cream)", borderRadius: 100, padding: "8px 16px",
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 12, cursor: "pointer",
          }}>Show all</button>
        )}
      </div>
    </div>
  );
}

function ChipScrollRow({ label, children }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "5px 0" }}>
      <div style={{
        flex: "0 0 auto", paddingLeft: 17, paddingRight: 4,
        fontFamily: "Apercu, sans-serif", fontSize: 9.5, fontWeight: 500,
        letterSpacing: "0.1em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.4)", width: 64,
      }}>{label}</div>
      <div style={{
        flex: 1, display: "flex", gap: 6, overflowX: "auto", paddingRight: 17,
        scrollbarWidth: "none",
      }}>{children}</div>
    </div>
  );
}

// ---------- Diet helper ----------
function passesDiet(formula, diet, allergens) {
  // exclude if formula's excludes intersects diet
  for (const d of diet) if (formula.excludes.includes(d)) return false;
  // exclude if formula's allergens intersects user's allergen list
  for (const a of allergens) if (formula.allergens.includes(a)) return false;
  return true;
}

Object.assign(window, { BrowserScreen, BeforeCard, DuringCard });

// ---------- Your Formulas section (top of each phase tab) ----------
// Always renders the header + count chip + "+ New" pill. When the phase has no
// personal formulas, shows a quiet placeholder card with two affordances.
// When "favorites only" is active and no personals are favorited, hides the
// entire section (header + empty card) so the tab focuses on system templates.
function YourFormulasSection({ phase, personalFormulas, totalPersonals, customFoods, isFavorite, toggleFavorite, favoritesOnly, onOpen, onCreate, highlightId }) {
  // `personalFormulas` arrives PRE-FILTERED by the caller (BeforeBody / DuringBody)
  // with the same predicates applied to system formulas — diet/allergens, sub-phase,
  // activity, duration, food form, gut, etc. We only layer favorites-only on top.
  const allForPhase = (personalFormulas || []).filter(p => p.sourcePhase === phase);
  const list = favoritesOnly
    ? allForPhase.filter(p => isFavorite && isFavorite("personal", p.id))
    : allForPhase;
  // `totalPersonals` is the unfiltered count for this phase — used to tell
  // "filtered out by active filters" apart from "you never made any".
  const total = (typeof totalPersonals === "number")
    ? totalPersonals
    : allForPhase.length;
  const filteredOut = total > 0 && allForPhase.length === 0;

  // When favoritesOnly is on and the user has no favorited personals, suppress
  // the section completely — the header + empty card would just be noise.
  if (favoritesOnly && list.length === 0) return null;
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{
        display: "flex", alignItems: "center", gap: 10, padding: "0 0 10px",
      }}>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 11, fontWeight: 500,
          letterSpacing: "0.1em", textTransform: "uppercase",
          color: "rgba(248,246,235,0.7)",
        }}>Your formulas</div>
        <span style={{
          display: "inline-flex", alignItems: "center", justifyContent: "center",
          minWidth: 24, height: 20, padding: "0 8px", borderRadius: 100,
          background: "rgba(247,139,20,0.18)", color: "var(--me-orange)",
          fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 11,
          fontVariantNumeric: "tabular-nums",
        }}>
          {total > 0 && allForPhase.length !== total
            ? <>{allForPhase.length}<span style={{ opacity: 0.55 }}>/{total}</span></>
            : list.length}
        </span>
        <div style={{ flex: 1 }} />
        {onCreate && <NewFormulaPill onClick={onCreate} />}
      </div>

      {list.length === 0 ? (
        filteredOut
          ? <FilteredOutYourFormulasCard count={total} />
          : <EmptyYourFormulasCard onCreate={onCreate} />
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {list.map(p => (
            <PersonalCard
              key={p.id}
              personal={p}
              customFoods={customFoods}
              isFavorite={isFavorite ? isFavorite("personal", p.id) : false}
              onToggleFavorite={() => toggleFavorite && toggleFavorite("personal", p.id)}
              onClick={() => onOpen(p)}
              highlight={highlightId === p.id}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// Shown when the user has personal formulas for this phase, but the current
// filters hide all of them. Quiet plum chip — same geometry as the empty card.
function FilteredOutYourFormulasCard({ count }) {
  return (
    <div style={{
      padding: "14px 16px", borderRadius: 14,
      background: "rgba(0,0,0,0.22)",
      display: "flex", alignItems: "center", gap: 10,
      fontFamily: "Apercu, sans-serif", fontSize: 12.5, lineHeight: 1.4,
      color: "rgba(248,246,235,0.6)",
    }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
           stroke="rgba(248,246,235,0.45)" strokeWidth="2.2" strokeLinecap="square"
           style={{ flex: "0 0 auto" }}>
        <path d="M3 5h18M6 12h12M10 19h4" />
      </svg>
      <span>None of your {count} formula{count === 1 ? "" : "s"} match the active filters.</span>
    </div>
  );
}

// "+ New" pill — smaller weight than section title, cream/neutral fill, mirrors
// "Make this mine" geometry from the detail header.
function NewFormulaPill({ onClick }) {
  return (
    <button onClick={onClick} aria-label="Create new formula" style={{
      height: 28, padding: "0 12px 0 9px", borderRadius: 100,
      background: "var(--me-cream)", color: "var(--me-blackberry)",
      border: "none", cursor: "pointer", display: "inline-flex",
      alignItems: "center", gap: 5,
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 11,
      flex: "0 0 auto",
    }}>
      <svg width="11" height="11" viewBox="0 0 24 24" fill="none"
           stroke="currentColor" strokeWidth="3" strokeLinecap="square">
        <path d="M12 5v14M5 12h14" />
      </svg>
      New
    </button>
  );
}

// Quiet empty-state card — dark plum chip styling, no border, no shadow.
function EmptyYourFormulasCard({ onCreate }) {
  return (
    <div style={{
      padding: "16px 16px 14px", borderRadius: 14,
      background: "rgba(0,0,0,0.22)",
      display: "flex", flexDirection: "column", gap: 12,
    }}>
      <div style={{
        fontFamily: "Compadre, Georgia, serif", fontSize: 15, lineHeight: 1.3,
        color: "var(--me-cream)",
      }}>No personal formulas yet.</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 12.5,
          color: "rgba(248,246,235,0.55)",
          display: "flex", alignItems: "center", gap: 8,
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none"
               stroke="rgba(248,246,235,0.4)" strokeWidth="2.4" strokeLinecap="square"
               style={{ flex: "0 0 auto", transform: "rotate(90deg)" }}>
            <path d="M6 9l6 6 6-6" />
          </svg>
          Make any template yours
        </div>
        <button onClick={onCreate} style={{
          background: "transparent", border: "none", cursor: "pointer",
          padding: 0, textAlign: "left",
          color: "var(--me-orange)",
          fontFamily: "Apercu, sans-serif", fontSize: 12.5, fontWeight: 500,
          display: "inline-flex", alignItems: "center", gap: 8,
        }}>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none"
               stroke="currentColor" strokeWidth="3" strokeLinecap="square"
               style={{ flex: "0 0 auto" }}>
            <path d="M12 5v14M5 12h14" />
          </svg>
          Create new formula
        </button>
      </div>
    </div>
  );
}

function PersonalCard({ personal, customFoods, onClick, highlight, isFavorite, onToggleFavorite }) {
  const isBefore = personal.sourcePhase === "before";
  const items = personal.items || [];
  const macros = isBefore ? window.macrosFromItems(items, customFoods) : null;
  // from-scratch formulas don't carry a source name — skip the eyebrow line.
  const isFromScratch = personal.provenance === "from_scratch" || !personal.sourceName;

  // Components display: "0.5 Banana · 4 Medjool Dates"
  const componentsText = items
    .map(it => isBefore ? window.itemLabel(it, { customFoods }) : (window.lookupFood(it.foodKey, customFoods)?.name || it.raw || "?"))
    .join("  ·  ");

  return (
    <div onClick={onClick} role="button" tabIndex={0}
      onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); onClick && onClick(); } }}
      style={{
        position: "relative", width: "100%", textAlign: "left", cursor: "pointer",
        background: "rgba(247,139,20,0.06)",
        border: "1px solid rgba(247,139,20,0.3)",
        borderRadius: 15, padding: "12px 14px 12px 50px",
        display: "flex", flexDirection: "column", gap: 8,
        boxSizing: "border-box",
        animation: highlight ? "fk-new-card-pulse 1500ms ease-out" : undefined,
      }}>
      {/* Person-with-pencil badge top-left */}
      <div style={{
        position: "absolute", left: 12, top: 12,
        width: 28, height: 28, borderRadius: "50%",
        background: "var(--me-orange)", color: "var(--me-cream)",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}>
        <window.PersonPencilIcon size={15} />
      </div>

      <div style={{ display: "flex", alignItems: "flex-start", gap: 10, paddingRight: 44 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 17,
            color: "var(--me-cream)", lineHeight: 1.15,
          }}>{personal.name}</div>
          {!isFromScratch && (
            <div style={{
              marginTop: 3,
              fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
              letterSpacing: "0.06em", textTransform: "uppercase",
              color: "var(--me-orange)",
            }}>From {personal.sourceName}</div>
          )}
        </div>
      </div>

      {/* Favorite star — absolutely positioned top-right; replaces the chevron */}
      <div style={{ position: "absolute", top: 4, right: 4 }}>
        <window.FavoriteStar active={isFavorite} onClick={onToggleFavorite} />
      </div>

      <div style={{
        fontFamily: "Compadre, Georgia, serif", fontSize: 13, lineHeight: 1.3,
        color: "rgba(248,246,235,0.7)",
      }}>{componentsText}</div>

      {isBefore && macros && (
        <div style={{
          display: "flex", gap: 10,
          fontFamily: "'Apercu Mono', monospace", fontSize: 10.5,
          color: "rgba(248,246,235,0.7)", fontVariantNumeric: "tabular-nums",
        }}>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
            <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--me-carbs)" }} />
            {macros.carbs}g
          </span>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
            <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--me-dragonfruit)" }} />
            {macros.protein}g
          </span>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
            <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--me-electrolyte)" }} />
            {macros.sodium}mg
          </span>
        </div>
      )}
    </div>
  );
}

Object.assign(window, { YourFormulasSection, PersonalCard });
