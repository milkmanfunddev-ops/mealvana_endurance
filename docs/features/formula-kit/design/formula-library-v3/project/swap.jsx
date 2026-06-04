// Formula Kit V3 — Real Swap sheet + Create Custom Food form.

const { useState: useStateS, useMemo: useMemoS, useRef: useRefS } = React;

// ---------- Recommended alternatives ----------
// Pick system foods of the same category (and same category bucket for "drink-ish"
// items like fluid/mix). Sort by carb-similarity to the source.
function getRecommendedSystemFoods(item, customFoods, excludeKey) {
  const food = window.lookupFood(item.foodKey, customFoods);
  if (!food) {
    // Unknown source — show a sane default set
    return Object.entries(window.FOOD_CATALOG)
      .slice(0, 8)
      .map(([key, f]) => ({ key, food: f }));
  }
  const cat = food.category;
  // Group categories that are reasonable swaps for each other
  const peerGroups = {
    solid: ["solid"],
    gel:   ["gel"],
    fluid: ["fluid", "mix"],
    mix:   ["mix", "fluid"],
    pill:  ["pill"],
  };
  const peers = peerGroups[cat] || [cat];
  const sourceCarbs = food.macros.c || 0;
  return Object.entries(window.FOOD_CATALOG)
    .filter(([key, f]) => peers.includes(f.category) && key !== excludeKey && key !== item.foodKey)
    .map(([key, f]) => ({ key, food: f, _delta: Math.abs((f.macros.c || 0) - sourceCarbs) }))
    .sort((a, b) => a._delta - b._delta);
}

// ---------- Swap sheet ----------
function SwapSheet({ item, mode, customFoods, onClose, onSelect, onOpenCreate, onToast }) {
  const addMode = mode === "add";
  const food = !addMode && item ? window.lookupFood(item.foodKey, customFoods) : null;
  const [query, setQuery] = useStateS("");
  const [myFoodsOpen, setMyFoodsOpen] = useStateS(false);

  const recommended = useMemoS(() => {
    if (addMode) {
      // All system foods, sorted alphabetically by name.
      return Object.entries(window.FOOD_CATALOG)
        .map(([key, f]) => ({ key, food: f }))
        .sort((a, b) => a.food.name.localeCompare(b.food.name));
    }
    return getRecommendedSystemFoods(item, customFoods);
  }, [item, customFoods, addMode]);
  const lc = query.trim().toLowerCase();

  const filteredMyFoods = useMemoS(() => {
    return (customFoods || []).filter(cf => !lc || cf.name.toLowerCase().includes(lc));
  }, [customFoods, lc]);

  const filteredRecommended = useMemoS(() => {
    if (!lc) return recommended;
    return recommended.filter(r => r.food.name.toLowerCase().includes(lc));
  }, [recommended, lc]);

  return (
    <div style={{
      position: "absolute", inset: 0, zIndex: 20,
      background: "var(--me-blackberry)",
      display: "flex", flexDirection: "column",
      animation: "fk-slide-up 220ms cubic-bezier(0.2,0.8,0.2,1)",
    }}>
      {/* Header */}
      <div style={{ padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10 }}>
        <button onClick={onClose} aria-label="Back" style={{
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
          flex: 1, textAlign: "center", paddingRight: 40,
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 19,
          color: "var(--me-cream)", lineHeight: 1.1,
          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
        }}>{addMode ? "Add Food" : `Swap ${food?.name || "Component"}`}</div>
      </div>

      {/* Search bar */}
      <div style={{ padding: "10px 17px 4px" }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 10,
          height: 44, padding: "0 14px", borderRadius: 100,
          background: "rgba(248,246,235,0.08)",
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
               stroke="var(--me-electrolyte)" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"
               style={{ flex: "0 0 auto" }}>
            <circle cx="11" cy="11" r="7" />
            <path d="M21 21l-4.35-4.35" />
          </svg>
          <input
            type="text" value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="Search for food…"
            style={{
              flex: 1, background: "transparent", border: "none", outline: "none",
              color: "var(--me-cream)",
              fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 400,
            }}
          />
          <button onClick={() => onToast && onToast("Barcode scan placeholder")} aria-label="Scan barcode" style={{
            width: 28, height: 28, background: "transparent", border: "none",
            cursor: "pointer", color: "var(--me-orange)",
            display: "flex", alignItems: "center", justifyContent: "center",
            flex: "0 0 auto",
          }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
              <path d="M4 6v12M8 6v12M12 6v12M16 6v12M20 6v12" />
            </svg>
          </button>
        </div>
      </div>

      {/* Create Custom Food */}
      <div style={{ padding: "12px 17px 6px", textAlign: "center" }}>
        <button onClick={onOpenCreate} style={{
          background: "transparent", border: "none", cursor: "pointer",
          color: "var(--me-orange)",
          fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500,
          display: "inline-flex", alignItems: "center", gap: 8,
          padding: "8px 10px",
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
               stroke="currentColor" strokeWidth="2.6" strokeLinecap="round">
            <path d="M12 5v14M5 12h14" />
          </svg>
          Create Custom Food
        </button>
      </div>

      {/* Scrollable content */}
      <div style={{ flex: 1, overflow: "auto", padding: "4px 17px 30px" }}>
        {/* My Foods */}
        <button onClick={() => setMyFoodsOpen(!myFoodsOpen)} style={{
          width: "100%", background: "transparent", border: "none", cursor: "pointer",
          padding: "10px 0", display: "flex", alignItems: "center", gap: 10,
          textAlign: "left",
        }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
               stroke="var(--me-orange)" strokeWidth="2.6" strokeLinecap="square"
               style={{
                 flex: "0 0 auto",
                 transform: myFoodsOpen ? "rotate(90deg)" : "rotate(0deg)",
                 transition: "transform 200ms cubic-bezier(0.2,0.8,0.2,1)",
               }}>
            <path d="M9 6l6 6-6 6" />
          </svg>
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 19,
            color: filteredMyFoods.length === 0 ? "rgba(248,246,235,0.55)" : "var(--me-cream)",
            lineHeight: 1.1,
          }}>My Foods</div>
          <CountChip count={filteredMyFoods.length} muted={filteredMyFoods.length === 0} />
        </button>
        {myFoodsOpen && (
          <div style={{ display: "flex", flexDirection: "column", gap: 8, padding: "4px 0 8px" }}>
            {filteredMyFoods.length === 0 ? (
              <div style={{
                padding: "12px 14px", borderRadius: 12,
                background: "rgba(248,246,235,0.03)",
                border: "1px dashed rgba(248,246,235,0.12)",
                fontFamily: "Apercu, sans-serif", fontSize: 12,
                color: "rgba(248,246,235,0.6)", lineHeight: 1.5,
              }}>
                {lc
                  ? <>No personal foods match "<span style={{ color: "var(--me-cream)" }}>{query}</span>".</>
                  : <>Use Create Custom Food above to add foods you've measured.</>}
              </div>
            ) : (
              filteredMyFoods.map(cf => (
                <SwapRow key={cf.key} food={cf} isPersonal onSelect={() => onSelect(cf.key)} />
              ))
            )}
          </div>
        )}

        {/* Recommended Alternatives */}
        <div style={{
          padding: "16px 0 8px",
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 19,
          color: "var(--me-cream)", lineHeight: 1.1,
        }}>{addMode ? "All Foods" : "Recommended Alternatives"}</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {filteredRecommended.length === 0 ? (
            <div style={{
              padding: "12px 14px", borderRadius: 12,
              background: "rgba(248,246,235,0.03)",
              border: "1px dashed rgba(248,246,235,0.12)",
              fontFamily: "Apercu, sans-serif", fontSize: 12,
              color: "rgba(248,246,235,0.6)",
            }}>
              No matches for "<span style={{ color: "var(--me-cream)" }}>{query}</span>".
            </div>
          ) : (
            filteredRecommended.map(({ key, food: f }) => (
              <SwapRow key={key} food={f} onSelect={() => onSelect(key)} />
            ))
          )}
        </div>
      </div>
    </div>
  );
}

function CountChip({ count, muted }) {
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", justifyContent: "center",
      minWidth: 32, height: 22, padding: "0 10px", borderRadius: 100,
      background: "rgba(0,0,0,0.32)",
      color: muted ? "rgba(248,246,235,0.55)" : "var(--me-orange)",
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 12,
      fontVariantNumeric: "tabular-nums",
      flex: "0 0 auto",
    }}>{count}</span>
  );
}

function SwapRow({ food, isPersonal, onSelect }) {
  return (
    <button onClick={onSelect} style={{
      width: "100%", textAlign: "left", cursor: "pointer",
      background: "transparent", border: "none",
      padding: "8px 4px", display: "flex", alignItems: "center", gap: 14,
    }}>
      <window.CategoryChip category={food.category} isPersonal={isPersonal || food.isPersonal} size={44} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 16,
          color: "var(--me-cream)", lineHeight: 1.15,
        }}>{food.name}</div>
        <div style={{
          marginTop: 3,
          fontFamily: "Apercu, sans-serif", fontSize: 12.5,
          color: "rgba(248,246,235,0.55)",
        }}>{Math.round(food.macros.c || 0)}g carbs per serving</div>
      </div>
      <div style={{
        width: 36, height: 36, borderRadius: "50%",
        background: "var(--me-orange)", color: "var(--me-cream)",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
             stroke="currentColor" strokeWidth="3" strokeLinecap="square">
          <path d="M12 5v14M5 12h14" />
        </svg>
      </div>
    </button>
  );
}

// ---------- Create Custom Food ----------
function CreateCustomFoodSheet({ onClose, onCreate }) {
  const [name, setName] = useStateS("");
  const [carbs, setCarbs] = useStateS("");
  const [protein, setProtein] = useStateS("");
  const [fat, setFat] = useStateS("");
  const [sodium, setSodium] = useStateS("");
  const [fluid, setFluid] = useStateS("");
  const [category, setCategory] = useStateS("solid");

  const canSave = name.trim().length > 0;

  const save = () => {
    if (!canSave) return;
    const food = {
      key: `cf-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      name: name.trim(),
      category, isPersonal: true,
      unit: null, step: 1,
      macros: {
        c: parseFloat(carbs) || 0,
        p: parseFloat(protein) || 0,
        f: parseFloat(fat) || 0,
        s: parseFloat(sodium) || 0,
        fl: parseFloat(fluid) || 0,
      },
    };
    onCreate(food);
  };

  return (
    <div style={{
      position: "absolute", inset: 0, zIndex: 30,
      background: "var(--me-blackberry)",
      display: "flex", flexDirection: "column",
      animation: "fk-slide-up 220ms cubic-bezier(0.2,0.8,0.2,1)",
    }}>
      {/* Header */}
      <div style={{ padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10 }}>
        <button onClick={onClose} style={{
          background: "transparent", border: "none", cursor: "pointer",
          color: "var(--me-cream)",
          fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500,
          padding: "8px 4px 8px 0", flex: "0 0 auto",
        }}>Cancel</button>
        <div style={{
          flex: 1, textAlign: "center", paddingRight: 60,
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 19,
          color: "var(--me-cream)", lineHeight: 1.1,
        }}>Create Custom Food</div>
        <button onClick={save} disabled={!canSave} style={{
          height: 36, padding: "0 18px", borderRadius: 100,
          background: canSave ? "var(--me-orange)" : "rgba(247,139,20,0.3)",
          color: canSave ? "var(--me-blackberry)" : "rgba(56,22,51,0.6)",
          border: "none", cursor: canSave ? "pointer" : "not-allowed",
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
        }}>Save</button>
      </div>

      <div style={{ flex: 1, overflow: "auto", padding: "14px 17px 30px" }}>
        <FieldLabel>Name</FieldLabel>
        <TextInput value={name} onChange={setName} placeholder="e.g., Homemade Energy Balls" />

        <div style={{ height: 20 }} />
        <FieldLabel>Category</FieldLabel>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap", paddingTop: 4 }}>
          {[
            { id: "solid", label: "Solid" },
            { id: "gel", label: "Gel" },
            { id: "fluid", label: "Fluid" },
            { id: "mix", label: "Drink mix" },
            { id: "pill", label: "Tablet" },
          ].map(o => (
            <button key={o.id} onClick={() => setCategory(o.id)} style={{
              height: 36, padding: "0 14px", borderRadius: 100,
              background: category === o.id ? "var(--me-cream)" : "transparent",
              color: category === o.id ? "var(--me-blackberry)" : "var(--me-cream)",
              border: `1px solid ${category === o.id ? "var(--me-cream)" : "rgba(248,246,235,0.18)"}`,
              fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 13,
              cursor: "pointer",
              display: "inline-flex", alignItems: "center", gap: 8,
            }}>
              <window.CategoryChip category={o.id} size={22} />
              {o.label}
            </button>
          ))}
        </div>

        <div style={{ height: 24 }} />
        <FieldLabel>Per serving</FieldLabel>
        <div style={{
          display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, paddingTop: 4,
        }}>
          <NumField label="Carbs (g)" value={carbs} onChange={setCarbs} />
          <NumField label="Protein (g)" value={protein} onChange={setProtein} />
          <NumField label="Fat (g)" value={fat} onChange={setFat} />
          <NumField label="Sodium (mg)" value={sodium} onChange={setSodium} />
          <NumField label="Fluid (ml)" value={fluid} onChange={setFluid} />
        </div>
      </div>
    </div>
  );
}

function FieldLabel({ children }) {
  return (
    <div style={{
      fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
      letterSpacing: "0.1em", textTransform: "uppercase",
      color: "rgba(248,246,235,0.5)", marginBottom: 6,
    }}>{children}</div>
  );
}

function TextInput({ value, onChange, placeholder }) {
  return (
    <input
      type="text" value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
      style={{
        width: "100%", height: 44, padding: "0 14px",
        background: "rgba(248,246,235,0.08)", border: "none", outline: "none",
        borderRadius: 12,
        color: "var(--me-cream)",
        fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500,
        boxSizing: "border-box",
      }}
    />
  );
}

function NumField({ label, value, onChange }) {
  return (
    <label style={{ display: "flex", flexDirection: "column", gap: 4 }}>
      <span style={{
        fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
        letterSpacing: "0.06em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.55)",
      }}>{label}</span>
      <input
        type="number" inputMode="decimal" min="0" step="0.1"
        value={value} onChange={(e) => onChange(e.target.value)}
        placeholder="0"
        style={{
          width: "100%", height: 44, padding: "0 14px",
          background: "rgba(248,246,235,0.08)", border: "none", outline: "none",
          borderRadius: 12,
          color: "var(--me-cream)",
          fontFamily: "'Apercu Mono', monospace", fontSize: 14, fontWeight: 500,
          fontVariantNumeric: "tabular-nums",
          boxSizing: "border-box",
        }}
      />
    </label>
  );
}

Object.assign(window, { SwapSheet, CreateCustomFoodSheet });
