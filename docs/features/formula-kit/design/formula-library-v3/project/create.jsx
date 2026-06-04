// Formula Kit V3 — Create-from-scratch flow.
// Full-screen sibling of the edit state; reuses ComponentRow / SwapSheet / InsightPanel.
//
// Entered from the YOUR FORMULAS header on either tab; phase is locked to the
// entry tab. Saves a personal formula with provenance "from_scratch".

const { useState: useStateC, useMemo: useMemoC, useEffect: useEffectC, useRef: useRefC } = React;

// Auto-title from current components — "Banana + Honey + Sports Drink".
function autoTitleFromItems(items, customFoods) {
  if (!items || items.length === 0) return "";
  const names = items.map(it => {
    const food = window.lookupFood(it.foodKey, customFoods);
    if (food) return food.name;
    return (it.raw || "Food");
  });
  // De-dupe while preserving order (e.g., two gels)
  const seen = new Set();
  const dedup = [];
  for (const n of names) {
    if (seen.has(n)) continue;
    seen.add(n);
    dedup.push(n);
  }
  return dedup.join(" + ");
}

function CreateScreen({ phase, customFoods, onCancel, onSave, onToast }) {
  const isBefore = phase === "before";

  // Components
  const [items, setItems] = useStateC([]);
  const [expandedIdx, setExpandedIdx] = useStateC(null);
  const [addingFood, setAddingFood] = useStateC(false);
  const [swapIdx, setSwapIdx] = useStateC(null);
  const [createOpen, setCreateOpen] = useStateC(false);

  // Title — auto vs custom
  const [customTitle, setCustomTitle] = useStateC(null); // null = auto
  const [titleEditing, setTitleEditing] = useStateC(false);
  const autoTitle = useMemoC(() => autoTitleFromItems(items, customFoods), [items, customFoods]);
  const displayTitle = customTitle != null ? customTitle : autoTitle;
  const titleInputRef = useRefC(null);
  useEffectC(() => {
    if (titleEditing && titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, [titleEditing]);

  // Phase metadata
  // Before
  const [subPhase, setSubPhase] = useStateC(null);
  // During
  const [activities, setActivities] = useStateC([]);
  const [durations, setDurations] = useStateC([]);
  const [gut, setGut] = useStateC("Moderate");

  // Macros panel — live from items (Before only); During shows the scales-to-plan card
  const liveMacros = useMemoC(() => {
    if (!isBefore) return null;
    if (items.length === 0) {
      return { carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 };
    }
    return window.macrosFromItems(items, customFoods);
  }, [items, customFoods, isBefore]);

  // Validation
  const missing = useMemoC(() => {
    const problems = [];
    if (isBefore) {
      if (!subPhase) problems.push("Pick a sub-phase to save");
    } else {
      if (activities.length === 0) problems.push("Pick at least one activity to save");
      if (durations.length === 0) problems.push("Pick at least one duration to save");
    }
    if (items.length === 0) problems.push("Add at least one food to save");
    return problems;
  }, [isBefore, subPhase, activities, durations, items]);
  const valid = missing.length === 0;

  // Item mutators
  const appendItem = (newFoodKey) => {
    const food = window.lookupFood(newFoodKey, customFoods);
    if (!food) return;
    const defaultQty = Math.max(food.step || 1, 0.5);
    const newItem = {
      id: `new-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      qty: defaultQty,
      foodKey: newFoodKey,
      raw: null,
    };
    setItems(prev => {
      setExpandedIdx(prev.length);
      return [...prev, newItem];
    });
    setAddingFood(false);
    onToast && onToast(`Added ${food.name}`);
  };
  const swapItem = (i, newFoodKey) => {
    const food = window.lookupFood(newFoodKey, customFoods);
    if (!food) return;
    const defaultQty = Math.max(food.step || 1, 0.5);
    setItems(prev => prev.map((x, idx) => idx === i ? { ...x, foodKey: newFoodKey, qty: defaultQty, raw: null } : x));
    setSwapIdx(null);
  };
  const incQty = (i) => {
    setItems(prev => prev.map((x, idx) => {
      if (idx !== i) return x;
      const food = window.lookupFood(x.foodKey, customFoods);
      const step = food?.step || 1;
      return { ...x, qty: parseFloat((x.qty + step).toFixed(4)) };
    }));
  };
  const decQty = (i) => {
    setItems(prev => prev.map((x, idx) => {
      if (idx !== i) return x;
      const food = window.lookupFood(x.foodKey, customFoods);
      const step = food?.step || 1;
      const min = window.itemMinQty(x, customFoods);
      const next = parseFloat((x.qty - step).toFixed(4));
      if (next < min - 0.0001) return x;
      return { ...x, qty: next };
    }));
  };
  const removeItem = (i) => {
    setItems(prev => prev.filter((_, idx) => idx !== i));
    setExpandedIdx(null);
  };

  // Save flow
  const handleSave = () => {
    if (!valid) {
      onToast && onToast(missing[0]);
      return;
    }
    const name = (displayTitle || "").trim() || autoTitle || "Untitled formula";
    const base = {
      id: `p-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      provenance: "from_scratch",
      sourceId: null,
      sourcePhase: phase,
      sourceName: null,
      name,
      items: items.map(it => ({ ...it })),
      allergens: [],
      excludes: [],
      addOns: [],
      createdAt: Date.now(),
    };
    let personal;
    if (isBefore) {
      personal = {
        ...base,
        category: "Custom",
        sub_phase: subPhase,
        // digestion is intentionally left blank — the coach insight can suggest a
        // sub-phase adjustment if the components don't match the chosen one.
        digestion: null,
        type: "food",
        // Compose a snapshot of components for legacy fields
        components: items.map(it => window.itemLabel(it, { customFoods })),
        macros: window.macrosFromItems(items, customFoods),
      };
    } else {
      personal = {
        ...base,
        activities: [...activities],
        durations: [...durations],
        gut: [gut],
        foodForm: "Custom",
        ratio: null,
        formula: name,
        components: items.map(it => {
          const food = window.lookupFood(it.foodKey, customFoods);
          return food?.name || it.raw || "Food";
        }),
      };
    }
    onSave(personal);
  };

  return (
    <div style={{
      position: "absolute", inset: 0, zIndex: 5,
      background: "var(--me-blackberry)",
      display: "flex", flexDirection: "column",
      color: "var(--me-cream)",
      animation: "fk-fade-in 180ms ease",
    }}>
      <CreateHeader onCancel={onCancel} onSave={handleSave} valid={valid} />

      <div style={{ flex: 1, overflow: "auto", padding: "0 17px 40px" }}>
        {/* Eyebrow */}
        <div style={{
          paddingTop: 4,
          fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
          letterSpacing: "0.08em", textTransform: "uppercase",
          color: "rgb(196,161,192)", marginBottom: 8,
        }}>New · {isBefore ? "Before" : "During"} formula</div>

        {/* Title */}
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
          <span style={{
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            width: 28, height: 28, borderRadius: "50%", background: "var(--me-orange)",
            color: "var(--me-cream)", flex: "0 0 auto",
          }}>
            <window.PersonPencilIcon size={15} />
          </span>
          {titleEditing ? (
            <input
              ref={titleInputRef}
              type="text"
              value={displayTitle}
              placeholder="Formula name"
              onChange={(e) => setCustomTitle(e.target.value)}
              onBlur={() => {
                setTitleEditing(false);
                // If user cleared the field, fall back to auto
                if ((customTitle || "").trim() === "") setCustomTitle(null);
              }}
              onKeyDown={(e) => { if (e.key === "Enter") e.target.blur(); }}
              style={{
                flex: 1, minWidth: 0, background: "transparent",
                border: "none", outline: "none",
                fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 26,
                color: "var(--me-cream)", lineHeight: 1.1, letterSpacing: "-0.01em",
                padding: "2px 0", borderBottom: "1.5px solid var(--me-orange)",
              }}
            />
          ) : (
            <button
              onClick={() => setTitleEditing(true)}
              style={{
                flex: 1, minWidth: 0, background: "transparent", border: "none",
                cursor: "text", textAlign: "left", padding: 0,
                fontFamily: "Sansita, Georgia, serif", fontWeight: 700,
                fontSize: 26, lineHeight: 1.1, letterSpacing: "-0.01em",
                color: displayTitle ? "var(--me-cream)" : "rgba(248,246,235,0.4)",
                fontStyle: displayTitle ? "normal" : "italic",
                overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap",
              }}
            >
              {displayTitle || "Title will appear as you add components"}
            </button>
          )}
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          {/* DETAILS */}
          <DetailsBlock
            isBefore={isBefore}
            subPhase={subPhase} setSubPhase={setSubPhase}
            activities={activities} setActivities={setActivities}
            durations={durations} setDurations={setDurations}
            gut={gut} setGut={setGut}
          />

          {/* MACROS */}
          {isBefore ? (
            <div style={{
              background: "rgba(248,246,235,0.04)",
              border: "1px solid rgba(196,161,192,0.25)",
              borderRadius: 15, padding: "12px 16px",
            }}>
              <window.EditableMacroRow macros={liveMacros} />
              <div style={{
                marginTop: 10,
                fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
                letterSpacing: "0.08em", textTransform: "uppercase",
                color: "rgba(196,161,192,0.85)",
              }}>Updates as you adjust components</div>
            </div>
          ) : (
            <div style={{
              background: "rgba(248,246,235,0.04)",
              border: "1px solid rgba(196,161,192,0.25)",
              borderRadius: 15, padding: "16px",
              display: "flex", flexDirection: "column", gap: 8,
            }}>
              <div style={{
                fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 15,
                color: "var(--me-cream)",
              }}>Scales to your plan</div>
              <div style={{
                fontFamily: "Apercu, sans-serif", fontSize: 12.5, lineHeight: 1.5,
                color: "rgba(248,246,235,0.7)",
              }}>During formulas don't carry absolute macros. Quantities scale to your hourly carb target at plan-generation time.</div>
              <div style={{
                marginTop: 4,
                fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
                letterSpacing: "0.08em", textTransform: "uppercase",
                color: "rgba(196,161,192,0.85)",
              }}>Updates as you adjust components</div>
            </div>
          )}

          {/* COACH INSIGHT */}
          {items.length === 0 ? (
            <InertInsightCard />
          ) : (
            <window.InsightPanel
              phase={phase}
              formula={{
                sourceName: null, name: displayTitle || "New formula",
                sub_phase: subPhase,
                foodForm: !isBefore ? "Custom" : undefined,
                ratio: null,
                durations,
                activities,
              }}
              items={items}
              macros={isBefore ? liveMacros : { carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 }}
              customFoods={customFoods}
            />
          )}

          {/* COMPONENTS */}
          <div>
            <div style={{
              fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
              letterSpacing: "0.1em", textTransform: "uppercase",
              color: "rgba(248,246,235,0.5)", marginBottom: 8,
            }}>Components</div>
            {items.length === 0 ? (
              <FirstFoodPrompt onAdd={() => setAddingFood(true)} />
            ) : (
              <>
                <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  {items.map((it, i) => (
                    <window.ComponentRow
                      key={(it.id || it.foodKey) + "-" + i}
                      item={it}
                      customFoods={customFoods}
                      variant={isBefore ? "before" : "during"}
                      expanded={expandedIdx === i}
                      canRemove={true}
                      onToggle={() => setExpandedIdx(expandedIdx === i ? null : i)}
                      onIncrement={() => incQty(i)}
                      onDecrement={() => decQty(i)}
                      onSwap={() => setSwapIdx(i)}
                      onRemove={() => removeItem(i)}
                    />
                  ))}
                </div>
                <div style={{ marginTop: 12, display: "flex", justifyContent: "center" }}>
                  <window.AddFoodButton onClick={() => setAddingFood(true)} />
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Swap sheet (re-used for both add + swap) */}
      {addingFood && (
        <window.SwapSheet
          mode="add"
          item={null}
          customFoods={customFoods}
          onClose={() => setAddingFood(false)}
          onSelect={(newKey) => appendItem(newKey)}
          onOpenCreate={() => setCreateOpen(true)}
          onToast={onToast}
        />
      )}
      {swapIdx != null && items[swapIdx] && (
        <window.SwapSheet
          item={items[swapIdx]}
          customFoods={customFoods}
          onClose={() => setSwapIdx(null)}
          onSelect={(newKey) => swapItem(swapIdx, newKey)}
          onOpenCreate={() => setCreateOpen(true)}
          onToast={onToast}
        />
      )}
      {createOpen && (
        <window.CreateCustomFoodSheet
          onClose={() => setCreateOpen(false)}
          onCreate={(food) => {
            window.__addCustomFood && window.__addCustomFood(food);
            setCreateOpen(false);
            if (addingFood) {
              appendItem(food.key);
            } else if (swapIdx != null && items[swapIdx]) {
              swapItem(swapIdx, food.key);
            }
            onToast && onToast(`Added ${food.name}`);
          }}
        />
      )}
    </div>
  );
}

// ---------- Sub-components ----------

function CreateHeader({ onCancel, onSave, valid }) {
  return (
    <div style={{ padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10 }}>
      <button onClick={onCancel} style={{
        background: "transparent", border: "none", cursor: "pointer",
        color: "var(--me-cream)",
        fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500,
        padding: "8px 4px 8px 0", flex: "0 0 auto",
      }}>Cancel</button>
      <div style={{
        flex: 1, textAlign: "center",
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 19,
        color: "var(--me-cream)", lineHeight: 1.1,
      }}>New formula</div>
      <button onClick={onSave} style={{
        height: 36, padding: "0 18px", borderRadius: 100,
        background: "var(--me-orange)",
        opacity: valid ? 1 : 0.5,
        color: "var(--me-blackberry)",
        border: "none", cursor: "pointer",
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
        flex: "0 0 auto",
        transition: "opacity 180ms ease",
      }}>Save</button>
    </div>
  );
}

function DetailsBlock({
  isBefore,
  subPhase, setSubPhase,
  activities, setActivities,
  durations, setDurations,
  gut, setGut,
}) {
  return (
    <div>
      <SectionLabel>Details</SectionLabel>
      <div style={{
        background: "rgba(248,246,235,0.04)",
        border: "1px solid rgba(248,246,235,0.08)",
        borderRadius: 15, padding: "14px 14px",
        display: "flex", flexDirection: "column", gap: 14,
      }}>
        {isBefore ? (
          <FieldRow label="Sub-phase" required
            help="Pick what feels right \u2014 the coach insight will flag mismatches if your components don't fit.">
            <PillRow>
              {window.SUB_PHASE_OPTS.map(sp => (
                <window.FilterChip key={sp.id} label={sp.label}
                  active={subPhase === sp.id}
                  onClick={() => setSubPhase(subPhase === sp.id ? null : sp.id)} />
              ))}
            </PillRow>
          </FieldRow>
        ) : (
          <>
            <FieldRow label="Activity" required multi>
              <ScrollPillRow>
                {window.ACTIVITY_OPTS.map(a => {
                  const active = activities.includes(a.id);
                  return (
                    <window.FilterChip key={a.id} label={a.label} active={active}
                      onClick={() => setActivities(active ? activities.filter(x => x !== a.id) : [...activities, a.id])}
                      leading={<window.ActivityIcon activity={a.id} size={11} />}
                    />
                  );
                })}
              </ScrollPillRow>
            </FieldRow>
            <FieldRow label="Duration" required multi>
              <PillRow>
                {window.DURING_DURATION_OPTS.map(d => {
                  const active = durations.includes(d.id);
                  return (
                    <window.FilterChip key={d.id} label={d.label} active={active}
                      onClick={() => setDurations(active ? durations.filter(x => x !== d.id) : [...durations, d.id])} />
                  );
                })}
              </PillRow>
            </FieldRow>
            <FieldRow label="Gut training" optional>
              <PillRow>
                {window.GUT_LEVEL_OPTS.map(o => (
                  <window.FilterChip key={o.id} label={o.label}
                    active={gut === o.id}
                    onClick={() => setGut(o.id)} />
                ))}
              </PillRow>
            </FieldRow>
          </>
        )}
      </div>
    </div>
  );
}

function SectionLabel({ children }) {
  return (
    <div style={{
      fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
      letterSpacing: "0.1em", textTransform: "uppercase",
      color: "rgba(248,246,235,0.5)", marginBottom: 8,
    }}>{children}</div>
  );
}

function FieldRow({ label, required, optional, multi, help, children }) {
  return (
    <div>
      <div style={{
        display: "flex", alignItems: "center", gap: 8, marginBottom: help ? 4 : 8,
      }}>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 11, fontWeight: 500,
          color: "var(--me-cream)",
        }}>{label}</div>
        {required && (
          <span style={{
            fontFamily: "Apercu, sans-serif", fontSize: 9, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "var(--me-orange)",
          }}>Required</span>
        )}
        {optional && (
          <span style={{
            fontFamily: "Apercu, sans-serif", fontSize: 9, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.4)",
          }}>Optional</span>
        )}
        {multi && (
          <span style={{
            fontFamily: "Apercu, sans-serif", fontSize: 9, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.4)",
          }}>Multi-select</span>
        )}
      </div>
      {help && (
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 11, lineHeight: 1.45,
          color: "rgba(248,246,235,0.55)", marginBottom: 8,
        }}>{help}</div>
      )}
      {children}
    </div>
  );
}

function PillRow({ children }) {
  return <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>{children}</div>;
}

function ScrollPillRow({ children }) {
  return (
    <div style={{
      display: "flex", gap: 6, overflowX: "auto",
      paddingBottom: 2,
      scrollbarWidth: "none",
    }}>{children}</div>
  );
}

function FirstFoodPrompt({ onAdd }) {
  return (
    <div style={{
      padding: "22px 16px",
      borderRadius: 15,
      background: "rgba(248,246,235,0.03)",
      border: "1px dashed rgba(248,246,235,0.16)",
      display: "flex", flexDirection: "column", alignItems: "center", gap: 14,
      textAlign: "center",
    }}>
      <div style={{
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 16,
        color: "var(--me-cream)",
      }}>Add your first food</div>
      <window.AddFoodButton onClick={onAdd} />
    </div>
  );
}

function InertInsightCard() {
  return (
    <div style={{
      borderRadius: 14,
      border: "1px solid rgba(248,246,235,0.08)",
      background: "rgba(248,246,235,0.02)",
      padding: "12px 14px",
      display: "flex", alignItems: "flex-start", gap: 12,
    }}>
      <div style={{
        width: 32, height: 32, borderRadius: "50%",
        background: "rgba(28,249,207,0.10)", color: "rgba(28,249,207,0.45)",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
             stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8" />
        </svg>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 14,
          color: "rgba(248,246,235,0.7)", lineHeight: 1.2,
        }}>Coach insight</div>
        <div style={{
          marginTop: 4,
          fontFamily: "Apercu, sans-serif", fontSize: 11.5, lineHeight: 1.45,
          color: "rgba(248,246,235,0.5)",
        }}>Add a component to get started. Once you add at least one food, I'll review your formula and offer suggestions.</div>
      </div>
    </div>
  );
}

Object.assign(window, { CreateScreen, DetailsBlock });
