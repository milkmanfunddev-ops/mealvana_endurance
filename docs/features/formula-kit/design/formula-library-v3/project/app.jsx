// Formula Kit V3 — App shell with persistence for personal formulas + custom foods.
const { useState, useEffect } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "diet": ["vegan", "gluten_free"],
  "allergens": []
}/*EDITMODE-END*/;

const STORAGE_KEYS = {
  personal: "mealvana.kit.personal_formulas",
  customFoods: "mealvana.kit.custom_foods",
  favorites: "mealvana.kit.favorites",
};

// Persisted state hook — JSON storage with a default fallback
function usePersistedState(key, fallback) {
  const [v, setV] = useState(() => {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return fallback;
      return JSON.parse(raw);
    } catch (e) { return fallback; }
  });
  useEffect(() => {
    try { localStorage.setItem(key, JSON.stringify(v)); } catch (e) {}
  }, [key, v]);
  return [v, setV];
}

function App() {
  const [phase, setPhase] = useState("before");
  const [route, setRoute] = useState({ name: "browser" });

  const [t, setTweak] = window.useTweaks(TWEAK_DEFAULTS);
  const [ignoreDiet, setIgnoreDiet] = useState(false);

  // Persisted state
  const [personalFormulas, setPersonalFormulas] = usePersistedState(STORAGE_KEYS.personal, []);
  const [customFoods, setCustomFoods] = usePersistedState(STORAGE_KEYS.customFoods, []);
  // Favorites — array of strings: "system:<id>" or "personal:<id>". Survives reloads.
  const [favorites, setFavorites] = usePersistedState(STORAGE_KEYS.favorites, []);
  // "Show favorites only" is a session-level filter; not persisted.
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const favKey = (kind, id) => `${kind}:${id}`;
  const isFavorite = (kind, id) => favorites.includes(favKey(kind, id));
  const toggleFavorite = (kind, id) => {
    const k = favKey(kind, id);
    setFavorites(prev => prev.includes(k) ? prev.filter(x => x !== k) : [...prev, k]);
  };

  // Expose addCustomFood globally so the CreateCustomFoodSheet can call it without prop drilling
  useEffect(() => {
    window.__addCustomFood = (food) => {
      setCustomFoods(prev => [...prev, food]);
    };
    return () => { delete window.__addCustomFood; };
  }, []);

  // Toast
  const [toast, setToast] = useState(null);
  const showToast = (msg) => {
    setToast(msg);
    setTimeout(() => setToast(t => t === msg ? null : t), 1800);
  };

  // Before filters
  const [beforeSubPhase, setBeforeSubPhase] = useState(null);
  const [beforeMore, setBeforeMore] = useState({ digestion: null, types: [] });
  // During filters
  const [duringActivity, setDuringActivity] = useState(null);
  const [duringDuration, setDuringDuration] = useState(null);
  const [duringMore, setDuringMore] = useState({ foodForms: [], gut: null });

  // Section collapse state
  const [collapsed, setCollapsed] = useState({});

  const [moreOpen, setMoreOpen] = useState(false);

  // Newly-created personal id — drives the brief background pulse on the list card.
  const [highlightId, setHighlightId] = useState(null);

  const openFormula = (formula) => setRoute({ name: "detail", source: "system", id: formula.id, phase });
  const openPersonal = (personal) => setRoute({ name: "detail", source: "personal", id: personal.id, phase: personal.sourcePhase });
  const openCreate = (forPhase) => setRoute({ name: "create", phase: forPhase || phase });
  const closeDetail = () => setRoute({ name: "browser" });

  const detailFormula = (() => {
    if (route.name !== "detail") return null;
    if (route.source === "personal") {
      return personalFormulas.find(p => p.id === route.id);
    }
    return (route.phase === "before"
      ? window.BEFORE_FORMULAS.find(f => f.id === route.id)
      : window.DURING_FORMULAS.find(f => f.id === route.id));
  })();

  // Personal formula CRUD
  const createPersonal = (personal) => {
    setPersonalFormulas(prev => [personal, ...prev]);
    return personal.id;
  };
  // Create-from-scratch save handler — commits the formula, jumps to its detail view,
  // and arms the pulse highlight so the list card flashes when the user returns.
  const createFromScratch = (personal) => {
    setPersonalFormulas(prev => [personal, ...prev]);
    setHighlightId(personal.id);
    setTimeout(() => setHighlightId((h) => (h === personal.id ? null : h)), 1800);
    setRoute({ name: "detail", source: "personal", id: personal.id, phase: personal.sourcePhase });
    showToast("Created in Your formulas.");
  };
  // Accepts a patch object so callers can update items + phase metadata in one go.
  const updatePersonal = (id, patch) => {
    setPersonalFormulas(prev => prev.map(p => p.id === id ? { ...p, ...patch, updatedAt: Date.now() } : p));
  };
  const deletePersonal = (id) => {
    setPersonalFormulas(prev => prev.filter(p => p.id !== id));
    // Prune from favorites so we don't carry a dead reference.
    setFavorites(prev => prev.filter(x => x !== favKey("personal", id)));
  };

  return (
    <div style={{
      minHeight: "100vh", background: "#1a0a17",
      display: "flex", alignItems: "center", justifyContent: "center", padding: 32,
      fontFamily: "Apercu, sans-serif",
    }}>
      <Phone>
        {route.name === "browser" && (
          <BrowserScreen
            phase={phase} setPhase={setPhase}
            diet={t.diet} allergens={t.allergens}
            ignoreDiet={ignoreDiet} setIgnoreDiet={setIgnoreDiet}
            beforeSubPhase={beforeSubPhase} setBeforeSubPhase={setBeforeSubPhase}
            duringActivity={duringActivity} setDuringActivity={setDuringActivity}
            duringDuration={duringDuration} setDuringDuration={setDuringDuration}
            beforeMore={beforeMore} duringMore={duringMore}
            collapsed={collapsed} setCollapsed={setCollapsed}
            moreOpen={moreOpen} setMoreOpen={setMoreOpen}
            personalFormulas={personalFormulas}
            customFoods={customFoods}
            favorites={favorites} isFavorite={isFavorite} toggleFavorite={toggleFavorite}
            favoritesOnly={favoritesOnly} setFavoritesOnly={setFavoritesOnly}
            onOpenFormula={openFormula}
            onOpenPersonal={openPersonal}
            onOpenCreate={openCreate}
            highlightId={highlightId}
          />
        )}
        {route.name === "create" && (
          <CreateScreen
            phase={route.phase}
            customFoods={customFoods}
            onCancel={() => setRoute({ name: "browser" })}
            onSave={createFromScratch}
            onToast={showToast}
          />
        )}
        {route.name === "detail" && detailFormula && (
          <DetailScreen
            formula={detailFormula}
            phase={route.phase}
            source={route.source}
            customFoods={customFoods}
            onBack={closeDetail}
            onCreatePersonal={createPersonal}
            onUpdatePersonal={updatePersonal}
            onDeletePersonal={deletePersonal}
            onToast={showToast}
          />
        )}

        {moreOpen && (
          <MoreFiltersSheet
            phase={phase}
            beforeMore={beforeMore} setBeforeMore={setBeforeMore}
            duringMore={duringMore} setDuringMore={setDuringMore}
            diet={t.diet} setDiet={(v) => setTweak("diet", v)}
            allergens={t.allergens} setAllergens={(v) => setTweak("allergens", v)}
            ignoreDiet={ignoreDiet} setIgnoreDiet={setIgnoreDiet}
            favoritesOnly={favoritesOnly} setFavoritesOnly={setFavoritesOnly}
            onClose={() => setMoreOpen(false)}
          />
        )}

        {toast && (
          <div style={{
            position: "absolute", top: 64, left: "50%", transform: "translateX(-50%)",
            zIndex: 40, padding: "10px 18px", borderRadius: 100,
            background: "var(--me-electrolyte)", color: "var(--me-blackberry)",
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
            boxShadow: "0 12px 30px rgba(0,0,0,0.5)",
            animation: "fk-toast 240ms cubic-bezier(0.2,0.8,0.2,1)",
            whiteSpace: "nowrap",
            pointerEvents: "none",
          }}>{toast}</div>
        )}
      </Phone>

      <window.TweaksPanel title="Tweaks">
        <window.TweakSection label="Dietary profile">
          {Object.entries(window.DIET_LABELS).map(([k, label]) => (
            <window.TweakToggle key={k} label={label}
              value={t.diet.includes(k)}
              onChange={(v) => setTweak("diet", v ? [...t.diet, k] : t.diet.filter(x => x !== k))}
            />
          ))}
        </window.TweakSection>
        <window.TweakSection label="Allergens">
          {["Gluten", "Dairy", "Peanut", "Tree Nut", "Egg"].map(a => (
            <window.TweakToggle key={a} label={a}
              value={t.allergens.includes(a)}
              onChange={(v) => setTweak("allergens", v ? [...t.allergens, a] : t.allergens.filter(x => x !== a))}
            />
          ))}
        </window.TweakSection>
        <window.TweakSection label="Storage (V3 demo)">
          <window.TweakButton label={`Clear personal formulas (${personalFormulas.length})`}
            onClick={() => setPersonalFormulas([])} />
          <window.TweakButton label={`Clear custom foods (${customFoods.length})`}
            onClick={() => setCustomFoods([])} />
        </window.TweakSection>
      </window.TweaksPanel>
    </div>
  );
}

function MoreFiltersSheet({ phase, beforeMore, setBeforeMore, duringMore, setDuringMore, diet, setDiet, allergens, setAllergens, ignoreDiet, setIgnoreDiet, favoritesOnly, setFavoritesOnly, onClose }) {
  const clearAll = () => {
    setDiet([]);
    setAllergens([]);
    setIgnoreDiet(false);
    setFavoritesOnly(false);
    if (phase === "before") setBeforeMore({ digestion: null, types: [] });
    else setDuringMore({ foodForms: [], gut: null });
  };
  const allergenList = ["Gluten", "Dairy", "Peanut", "Tree Nut", "Egg"];
  return (
    <>
      <div onClick={onClose} style={{
        position: "absolute", inset: 0, background: "rgba(0,0,0,0.5)", zIndex: 10,
      }} />
      <div style={{
        position: "absolute", left: 0, right: 0, bottom: 0, zIndex: 11,
        background: "var(--me-blackberry)",
        borderTop: "1px solid rgba(248,246,235,0.1)",
        borderTopLeftRadius: 24, borderTopRightRadius: 24,
        padding: "16px 17px 22px",
        display: "flex", flexDirection: "column", gap: 16,
        maxHeight: "75%", overflow: "auto",
        boxShadow: "0 -20px 60px rgba(0,0,0,0.5)",
      }}>
        <div style={{
          width: 36, height: 4, borderRadius: 2,
          background: "rgba(248,246,235,0.2)", margin: "0 auto",
        }} />
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 20,
            color: "var(--me-cream)",
          }}>More filters</div>
          <button onClick={clearAll} style={{
            background: "transparent", border: "none", color: "var(--me-orange)",
            fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500, cursor: "pointer", padding: 0,
          }}>Reset</button>
        </div>

        <SheetSection label="Dietary profile">
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {Object.entries(window.DIET_LABELS).map(([k, label]) => {
              const active = diet.includes(k);
              return (
                <window.FilterChip key={k} label={label} active={active}
                  onClick={() => setDiet(active ? diet.filter(x => x !== k) : [...diet, k])}
                />
              );
            })}
          </div>
        </SheetSection>
        <SheetSection label="Favorites">
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            <window.FilterChip label="Show favorites only" active={favoritesOnly}
              onClick={() => setFavoritesOnly(!favoritesOnly)} />
          </div>
        </SheetSection>
        <SheetSection label="Allergens to avoid">
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {allergenList.map(a => {
              const active = allergens.includes(a);
              return (
                <window.FilterChip key={a} label={a} active={active}
                  onClick={() => setAllergens(active ? allergens.filter(x => x !== a) : [...allergens, a])}
                />
              );
            })}
          </div>
        </SheetSection>
        <SheetSection label="Show all (ignore diet & allergens)">
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            <window.FilterChip label={ignoreDiet ? "Ignoring diet" : "Apply diet"} active={ignoreDiet}
              onClick={() => setIgnoreDiet(!ignoreDiet)} />
          </div>
        </SheetSection>

        {phase === "before" ? (
          <>
            <SheetSection label="Digestion speed">
              <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                {window.DIGESTION_OPTS.map(o => (
                  <window.FilterChip key={o.id} label={o.label}
                    active={beforeMore.digestion === o.id}
                    onClick={() => setBeforeMore({ ...beforeMore, digestion: beforeMore.digestion === o.id ? null : o.id })}
                  />
                ))}
              </div>
            </SheetSection>
          </>
        ) : (
          <>
            <SheetSection label="Food form">
              <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                {window.FOOD_FORM_OPTS.map(o => {
                  const active = duringMore.foodForms.includes(o.id);
                  return (
                    <window.FilterChip key={o.id} label={o.label} active={active}
                      onClick={() => setDuringMore({ ...duringMore, foodForms: active ? duringMore.foodForms.filter(x => x !== o.id) : [...duringMore.foodForms, o.id] })}
                    />
                  );
                })}
              </div>
            </SheetSection>
            <SheetSection label="Gut training level">
              <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                {window.GUT_LEVEL_OPTS.map(o => (
                  <window.FilterChip key={o.id} label={o.label}
                    active={duringMore.gut === o.id}
                    onClick={() => setDuringMore({ ...duringMore, gut: duringMore.gut === o.id ? null : o.id })}
                  />
                ))}
              </div>
            </SheetSection>
          </>
        )}

        <button onClick={onClose} style={{
          marginTop: 6, width: "100%", height: 48, borderRadius: 100,
          background: "var(--me-orange)", color: "var(--me-blackberry)",
          border: "none", fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 15,
          cursor: "pointer",
        }}>Apply</button>
      </div>
    </>
  );
}

function SheetSection({ label, children }) {
  return (
    <div>
      <div style={{
        fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
        letterSpacing: "0.1em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.5)", marginBottom: 8,
      }}>{label}</div>
      {children}
    </div>
  );
}

function Phone({ children }) {
  return (
    <div style={{
      width: 390, height: 820, background: "var(--me-blackberry)",
      borderRadius: 44, overflow: "hidden", position: "relative",
      boxShadow: "0 30px 80px -20px rgba(0,0,0,0.7), 0 0 0 8px #0a0a0a, 0 0 0 9px #2a2a2a",
      display: "flex", flexDirection: "column",
    }}>
      <div style={{
        height: 44, background: "var(--me-blackberry)", display: "flex",
        alignItems: "center", justifyContent: "space-between", padding: "12px 28px 0",
        fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500, color: "var(--me-cream)",
        flex: "0 0 auto",
      }}>
        <span>9:41</span>
        <span style={{ fontSize: 11, opacity: 0.85 }}>●●●●● 5G</span>
      </div>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden", position: "relative" }}>
        {children}
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
