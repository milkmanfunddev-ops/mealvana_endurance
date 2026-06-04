// Detail screen — handles system AND personal formulas, Before AND During.
// V3 iteration 2:
//  - personal source = "personal" formula opened from YOUR FORMULAS section
//  - read state shows the "Make this mine" pill for system formulas, "Edit" pill for personal
//  - edit state lets the user mutate items; Save creates (system) or updates (personal) a personal formula
//  - During edit variant: rows expand to Swap + Remove only (no qty stepper, no live macros)

const { useState: useStateD, useMemo: useMemoD, useEffect: useEffectD } = React;

function DetailScreen({
  formula,            // system formula OR personal formula
  phase,              // "before" | "during"
  source,             // "system" | "personal"
  customFoods,
  onBack,
  onCreatePersonal,   // (draftFormula) => personalId
  onUpdatePersonal,   // (personalId, items) => void
  onDeletePersonal,   // (personalId) => void
  onToast,
}) {
  const isBefore = phase === "before";
  const isPersonal = source === "personal";

  // For personal formulas: items live ON the formula. For system: parse from components.
  const baseItems = useMemoD(() => {
    if (isPersonal && formula.items) return formula.items.map(it => ({ ...it }));
    return window.componentsToItems(formula);
  }, [formula.id]);

  const [editing, setEditing] = useStateD(false);
  const [draftItems, setDraftItems] = useStateD(null);
  // Phase metadata draft — sub_phase for Before, activities/durations/gut for During.
  // Mirrors the DetailsBlock state shape so we can reuse the same control.
  const [draftMeta, setDraftMeta] = useStateD(null);
  const [expandedIdx, setExpandedIdx] = useStateD(null);
  const [swapIdx, setSwapIdx] = useStateD(null);
  const [createOpen, setCreateOpen] = useStateD(false);
  const [addingFood, setAddingFood] = useStateD(false);
  const [confirmDelete, setConfirmDelete] = useStateD(false);

  // When the formula identity changes, exit edit mode
  useEffectD(() => {
    setEditing(false);
    setDraftItems(null);
    setDraftMeta(null);
    setExpandedIdx(null);
    setSwapIdx(null);
    setCreateOpen(false);
    setAddingFood(false);
    setConfirmDelete(false);
  }, [formula.id]);

  const enterEdit = () => {
    setDraftItems(baseItems.map(it => ({ ...it })));
    setDraftMeta({
      sub_phase: formula.sub_phase || null,
      activities: [...(formula.activities || [])],
      durations: [...(formula.durations || [])],
      gut: (formula.gut && formula.gut[0]) || "Moderate",
    });
    setEditing(true);
    setExpandedIdx(null);
  };
  const cancelEdit = () => {
    setEditing(false);
    setDraftItems(null);
    setDraftMeta(null);
    setExpandedIdx(null);
    setSwapIdx(null);
    setConfirmDelete(false);
  };
  const saveEdit = () => {
    // Build a phase-metadata patch from draftMeta.
    const metaPatch = isBefore
      ? { sub_phase: draftMeta?.sub_phase || null }
      : {
          activities: [...((draftMeta && draftMeta.activities) || [])],
          durations: [...((draftMeta && draftMeta.durations) || [])],
          gut: [(draftMeta && draftMeta.gut) || "Moderate"],
        };
    if (isPersonal) {
      onUpdatePersonal && onUpdatePersonal(formula.id, {
        items: draftItems.map(it => ({ ...it })),
        ...metaPatch,
      });
      onToast && onToast("Saved");
      setEditing(false); setDraftItems(null); setDraftMeta(null); setExpandedIdx(null); setSwapIdx(null);
    } else {
      // Create a new personal formula (system → personal fork).
      const personal = {
        id: `p-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
        provenance: "forked",
        sourceId: formula.id,
        sourcePhase: phase,
        sourceName: formula.name,
        name: formula.name,
        // mirror these for rendering
        category: formula.category,
        digestion: formula.digestion,
        type: formula.type,
        allergens: formula.allergens || [],
        excludes: formula.excludes || [],
        addOns: formula.addOns || [],
        items: draftItems.map(it => ({ ...it })),
        // During-only mirrors — overridden by metaPatch below
        foodForm: formula.foodForm,
        ratio: formula.ratio,
        components: formula.components,
        createdAt: Date.now(),
        ...metaPatch,
      };
      onCreatePersonal && onCreatePersonal(personal);
      onToast && onToast("Saved to your formulas");
      setEditing(false); setDraftItems(null); setDraftMeta(null); setExpandedIdx(null); setSwapIdx(null);
    }
  };

  const items = editing ? draftItems : baseItems;
  const liveMacros = useMemoD(() => {
    if (!items) return formula.macros;
    return window.macrosFromItems(items, customFoods);
  }, [items, customFoods]);

  // Item mutators
  const incQty = (i) => {
    const it = draftItems[i];
    const food = window.lookupFood(it.foodKey, customFoods);
    const step = food?.step || 1;
    setDraftItems(draftItems.map((x, idx) => idx === i ? { ...x, qty: parseFloat((x.qty + step).toFixed(4)) } : x));
  };
  const decQty = (i) => {
    const it = draftItems[i];
    const food = window.lookupFood(it.foodKey, customFoods);
    const step = food?.step || 1;
    const min = window.itemMinQty(it, customFoods);
    const next = parseFloat((it.qty - step).toFixed(4));
    if (next < min - 0.0001) return;
    setDraftItems(draftItems.map((x, idx) => idx === i ? { ...x, qty: next } : x));
  };
  const removeItem = (i) => {
    if (draftItems.length <= 1) return;
    setDraftItems(draftItems.filter((_, idx) => idx !== i));
    setExpandedIdx(null);
  };
  const swapItem = (i, newFoodKey) => {
    const food = window.lookupFood(newFoodKey, customFoods);
    if (!food) return;
    const defaultQty = Math.max(food.step || 1, 0.5);
    setDraftItems(draftItems.map((x, idx) => idx === i ? {
      ...x, foodKey: newFoodKey, qty: defaultQty, raw: null,
    } : x));
    setSwapIdx(null);
  };
  const appendItem = (newFoodKey) => {
    const food = window.lookupFood(newFoodKey, customFoods);
    if (!food) return;
    const defaultQty = Math.max(food.step || 1, 0.5);
    const newItem = {
      id: `${formula.id}-add-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      qty: defaultQty,
      foodKey: newFoodKey,
      raw: null,
    };
    setDraftItems([...(draftItems || []), newItem]);
    setAddingFood(false);
    // Expand the newly-added row so the user lands on its details
    setExpandedIdx((draftItems || []).length);
    onToast && onToast(`Added ${food.name}`);
  };
  const deletePersonal = () => {
    onDeletePersonal && onDeletePersonal(formula.id);
    onToast && onToast("Formula deleted");
    onBack && onBack();
  };

  const rightNode = !editing && (
    isPersonal
      ? <window.EditPillButton onClick={enterEdit} />
      : <window.MakeMineButton onClick={enterEdit} />
  );

  return (
    <div style={{
      flex: 1, display: "flex", flexDirection: "column", background: "var(--me-blackberry)",
      color: "var(--me-cream)", overflow: "hidden", position: "relative",
    }}>
      {editing
        ? <EditHeader onCancel={cancelEdit} onSave={saveEdit} />
        : <ReadHeader onBack={onBack} rightNode={rightNode} />}

      <div style={{ flex: 1, overflow: "auto", padding: "0 17px 40px" }}>
        <div style={{ paddingTop: 8, paddingBottom: 18 }}>
          <Eyebrow editing={editing} isPersonal={isPersonal} formula={formula} phase={phase} />
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 28,
            color: "var(--me-cream)", lineHeight: 1.1, letterSpacing: "-0.01em",
            display: "flex", alignItems: "center", gap: 10,
          }}>
            {isPersonal && (
              <span style={{
                display: "inline-flex", alignItems: "center", justifyContent: "center",
                width: 28, height: 28, borderRadius: "50%", background: "var(--me-orange)",
                color: "var(--me-cream)", flex: "0 0 auto",
              }}>
                <window.PersonPencilIcon size={15} />
              </span>
            )}
            {formula.name}
          </div>
          {!isBefore && (
            <div style={{
              fontFamily: "'Apercu Mono', monospace", fontSize: 13,
              color: "rgba(248,246,235,0.6)", marginTop: 8,
            }}>{formula.formula || formula.components.join(" + ")}</div>
          )}
        </div>

        {isBefore ? (
          <BeforeDetail
            formula={formula}
            items={items}
            customFoods={customFoods}
            macros={liveMacros}
            editing={editing}
            isPersonal={isPersonal}
            draftMeta={draftMeta} setDraftMeta={setDraftMeta}
            expandedIdx={expandedIdx}
            onToggleRow={(i) => setExpandedIdx(expandedIdx === i ? null : i)}
            onIncrement={incQty}
            onDecrement={decQty}
            onRemove={removeItem}
            onSwap={(i) => setSwapIdx(i)}
            onAddFood={() => setAddingFood(true)}
            confirmDelete={confirmDelete}
            onAskDelete={() => setConfirmDelete(true)}
            onCancelDelete={() => setConfirmDelete(false)}
            onDelete={deletePersonal}
          />
        ) : (
          <DuringDetail
            formula={formula}
            items={items}
            customFoods={customFoods}
            editing={editing}
            isPersonal={isPersonal}
            draftMeta={draftMeta} setDraftMeta={setDraftMeta}
            expandedIdx={expandedIdx}
            onToggleRow={(i) => setExpandedIdx(expandedIdx === i ? null : i)}
            onRemove={removeItem}
            onSwap={(i) => setSwapIdx(i)}
            onAddFood={() => setAddingFood(true)}
            confirmDelete={confirmDelete}
            onAskDelete={() => setConfirmDelete(true)}
            onCancelDelete={() => setConfirmDelete(false)}
            onDelete={deletePersonal}
          />
        )}
      </div>

      {swapIdx != null && draftItems && (
        <window.SwapSheet
          item={draftItems[swapIdx]}
          customFoods={customFoods}
          onClose={() => setSwapIdx(null)}
          onSelect={(newKey) => swapItem(swapIdx, newKey)}
          onOpenCreate={() => setCreateOpen(true)}
          onToast={onToast}
        />
      )}

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

      {createOpen && (
        <window.CreateCustomFoodSheet
          onClose={() => setCreateOpen(false)}
          onCreate={(food) => {
            window.__addCustomFood && window.__addCustomFood(food);
            setCreateOpen(false);
            // route the result based on where the form was opened from
            if (addingFood) {
              appendItem(food.key);
            } else if (swapIdx != null && draftItems) {
              swapItem(swapIdx, food.key);
            }
            onToast && onToast(`Added ${food.name}`);
          }}
        />
      )}
    </div>
  );
}

function Eyebrow({ editing, isPersonal, formula, phase }) {
  let label;
  let color;
  if (editing) {
    // Draft eyebrow — drops the "From X" suffix for from-scratch personals.
    const isFromScratch = formula.provenance === "from_scratch" || !formula.sourceName;
    label = isFromScratch && isPersonal
      ? <>Draft · {phase === "before" ? "Before" : "During"} formula</>
      : <>Draft · From {formula.sourceName || formula.name}</>;
    color = "rgb(196,161,192)"; // dusty lavender
  } else if (isPersonal) {
    // From-scratch personal formulas have no source — show just "YOUR FORMULA".
    const isFromScratch = formula.provenance === "from_scratch" || !formula.sourceName;
    label = isFromScratch
      ? <>Your formula</>
      : <>Your formula · From {formula.sourceName}</>;
    color = "var(--me-cream)";
  } else {
    const isBefore = phase === "before";
    label = <>{window.PHASE_LABEL[phase]}{isBefore ? ` · ${formula.category}` : ""}</>;
    color = window.PHASE_TINT[phase];
  }
  return (
    <div style={{
      fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
      letterSpacing: "0.08em", textTransform: "uppercase",
      color, marginBottom: 8,
    }}>{label}</div>
  );
}

// ---------- Headers ----------
function ReadHeader({ onBack, rightNode }) {
  return (
    <div style={{ padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10 }}>
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
      }}>Template</div>
      {rightNode}
    </div>
  );
}

function EditHeader({ onCancel, onSave }) {
  return (
    <div style={{ padding: "14px 17px 10px", display: "flex", alignItems: "center", gap: 10 }}>
      <button onClick={onCancel} style={{
        background: "transparent", border: "none", cursor: "pointer",
        color: "var(--me-cream)",
        fontFamily: "Apercu, sans-serif", fontSize: 14, fontWeight: 500,
        padding: "8px 4px 8px 0", flex: "0 0 auto",
      }}>Cancel</button>
      <div style={{
        flex: 1,
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 22,
        color: "var(--me-cream)", lineHeight: 1.1, textAlign: "center",
      }}>Edit</div>
      <button onClick={onSave} style={{
        height: 36, padding: "0 18px", borderRadius: 100,
        background: "var(--me-orange)", color: "var(--me-blackberry)",
        border: "none", cursor: "pointer",
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
      }}>Save</button>
    </div>
  );
}

// ---------- Before detail body ----------
function BeforeDetail({
  formula, items, customFoods, macros, editing, isPersonal,
  draftMeta, setDraftMeta,
  expandedIdx, onToggleRow, onIncrement, onDecrement, onRemove, onSwap, onAddFood,
  confirmDelete, onAskDelete, onCancelDelete, onDelete,
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
        {formula.digestion && <window.InfoPill label={`${formula.digestion} digest`} />}
        {editing && <window.InfoPill label="Editing" tone="accent" />}
      </div>

      {/* Editable phase metadata — only in edit mode. */}
      {editing && draftMeta && (
        <window.DetailsBlock
          isBefore={true}
          subPhase={draftMeta.sub_phase}
          setSubPhase={(v) => setDraftMeta({ ...draftMeta, sub_phase: v })}
          activities={[]} setActivities={() => {}}
          durations={[]} setDurations={() => {}}
          gut="Moderate" setGut={() => {}}
        />
      )}

      {/* Macros panel — live in edit state */}
      <div style={{
        background: "rgba(248,246,235,0.04)",
        border: `1px solid ${editing ? "rgba(196,161,192,0.25)" : "rgba(248,246,235,0.08)"}`,
        borderRadius: 15, padding: "12px 16px",
        transition: "border-color 240ms",
      }}>
        {editing
          ? <window.EditableMacroRow macros={macros} />
          : <window.MacroRow macros={macros} />}
        {!editing && (
          <div style={{
            marginTop: 12,
            fontFamily: "Compadre, Georgia, serif", fontSize: 14.5, lineHeight: 1.4,
            color: "var(--me-cream)",
          }}>
            {items.map(it => window.itemLabel(it, { customFoods })).join("  ·  ")}
          </div>
        )}
        {editing && (
          <div style={{
            marginTop: 10,
            fontFamily: "Apercu, sans-serif", fontSize: 10.5, fontWeight: 500,
            letterSpacing: "0.08em", textTransform: "uppercase",
            color: "rgba(196,161,192,0.85)",
          }}>Updates as you adjust components</div>
        )}
      </div>

      {editing && (
        <window.InsightPanel
          phase="before"
          formula={formula}
          items={items}
          macros={macros}
          customFoods={customFoods}
        />
      )}

      <div>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
          letterSpacing: "0.1em", textTransform: "uppercase",
          color: "rgba(248,246,235,0.5)", marginBottom: 8,
        }}>Components</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map((it, i) => (
            editing ? (
              <window.ComponentRow
                key={(it.id || it.foodKey) + "-" + i}
                item={it}
                customFoods={customFoods}
                variant="before"
                expanded={expandedIdx === i}
                canRemove={items.length > 1}
                onToggle={() => onToggleRow(i)}
                onIncrement={() => onIncrement(i)}
                onDecrement={() => onDecrement(i)}
                onSwap={() => onSwap(i)}
                onRemove={() => onRemove(i)}
              />
            ) : (
              <ReadComponentRow key={(it.id || it.foodKey) + "-" + i} item={it} customFoods={customFoods} />
            )
          ))}
        </div>
        {editing && (
          <div style={{ marginTop: 12, display: "flex", justifyContent: "center" }}>
            <window.AddFoodButton onClick={onAddFood} />
          </div>
        )}
        {editing && isPersonal && (
          <DeleteSection
            confirm={confirmDelete}
            onAsk={onAskDelete}
            onCancel={onCancelDelete}
            onDelete={onDelete}
          />
        )}
      </div>

      {!editing && (formula.addOns || []).length > 0 && (
        <div>
          <div style={{
            fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
            letterSpacing: "0.1em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.5)", marginBottom: 8,
          }}>Optional add-ons</div>
          <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
            {formula.addOns.map(a => (
              <span key={a} style={{
                display: "inline-flex", alignItems: "center", height: 26, padding: "0 12px",
                borderRadius: 100, border: "1px dashed rgba(28,249,207,0.45)",
                color: "var(--me-electrolyte)",
                fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
              }}>{a}</span>
            ))}
          </div>
        </div>
      )}

      {!editing && <DietTags allergens={formula.allergens || []} excludes={formula.excludes || []} />}
    </div>
  );
}

function ReadComponentRow({ item, customFoods }) {
  const food = window.lookupFood(item.foodKey, customFoods);
  const category = food?.category || "solid";
  const isPersonal = !!food?.isPersonal;
  return (
    <div style={{
      borderRadius: 14,
      background: "rgba(248,246,235,0.025)",
      border: "1px solid rgba(248,246,235,0.08)",
      padding: "10px 12px", display: "flex", alignItems: "center", gap: 12,
    }}>
      <window.CategoryChip category={category} isPersonal={isPersonal} size={36} />
      <div style={{
        flex: 1, minWidth: 0,
        fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 15.5,
        color: "var(--me-cream)", lineHeight: 1.2,
        fontVariantNumeric: "tabular-nums",
      }}>{window.itemLabel(item, { customFoods })}</div>
    </div>
  );
}

// ---------- During detail body ----------
function DuringDetail({
  formula, items, customFoods, editing, isPersonal,
  draftMeta, setDraftMeta,
  expandedIdx, onToggleRow, onRemove, onSwap, onAddFood,
  confirmDelete, onAskDelete, onCancelDelete, onDelete,
}) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
        <window.InfoPill label={formula.foodForm} tone="success" />
        {formula.ratio && <window.InfoPill label={`Ratio ${formula.ratio}`} tone="mono" />}
        {editing && <window.InfoPill label="Editing" tone="accent" />}
      </div>

      {/* Editable phase metadata in edit mode — hides the read-only activity/duration
          chips below since the DetailsBlock subsumes them. */}
      {editing && draftMeta ? (
        <window.DetailsBlock
          isBefore={false}
          subPhase={null} setSubPhase={() => {}}
          activities={draftMeta.activities}
          setActivities={(v) => setDraftMeta({ ...draftMeta, activities: v })}
          durations={draftMeta.durations}
          setDurations={(v) => setDraftMeta({ ...draftMeta, durations: v })}
          gut={draftMeta.gut}
          setGut={(v) => setDraftMeta({ ...draftMeta, gut: v })}
        />
      ) : (
        <>
          <div>
            <div style={{
              fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
              letterSpacing: "0.1em", textTransform: "uppercase",
              color: "rgba(248,246,235,0.5)", marginBottom: 8,
            }}>Activities</div>
            <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
              {(formula.activities || []).map(a => <window.ActivityTag key={a} activity={a} />)}
            </div>
          </div>

          <div style={{ display: "flex", gap: 24, flexWrap: "wrap" }}>
            <DurList
              label="Duration"
              items={(formula.durations || []).map(d => ({ "<90":"< 90 min","90-150":"90–150 min","150-240":"150–240 min",">240":"> 240 min" }[d] || d))}
              mono
            />
            <DurList label="Gut training" items={formula.gut || []} />
          </div>
        </>
      )}

      {editing && (
        <window.InsightPanel
          phase="during"
          formula={formula}
          items={items}
          macros={{ carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 }}
          customFoods={customFoods}
        />
      )}

      {/* Components panel — rows in personal/edit mode; compact text in system read mode */}
      <div>
        <div style={{
          fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
          letterSpacing: "0.1em", textTransform: "uppercase",
          color: "rgba(248,246,235,0.5)", marginBottom: 8,
        }}>Components</div>
        {(isPersonal || editing) ? (
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {items.map((it, i) => (
              editing ? (
                <window.ComponentRow
                  key={(it.id || it.foodKey) + "-" + i}
                  item={it}
                  customFoods={customFoods}
                  variant="during"
                  expanded={expandedIdx === i}
                  canRemove={items.length > 1}
                  onToggle={() => onToggleRow(i)}
                  onSwap={() => onSwap(i)}
                  onRemove={() => onRemove(i)}
                />
              ) : (
                <DuringReadRow key={(it.id || it.foodKey) + "-" + i} item={it} customFoods={customFoods} />
              )
            ))}
          </div>
        ) : (          <div style={{
            background: "rgba(248,246,235,0.04)",
            border: "1px solid rgba(248,246,235,0.08)",
            borderRadius: 15, padding: "14px 16px",
          }}>
            <div style={{
              fontFamily: "Compadre, Georgia, serif", fontSize: 15, lineHeight: 1.4,
              color: "var(--me-cream)",
            }}>{formula.components.join(", ")}</div>
            <div style={{
              marginTop: 12, padding: "10px 12px", borderRadius: 10,
              background: "rgba(247,139,20,0.08)",
              fontFamily: "Apercu, sans-serif", fontSize: 11.5, fontStyle: "italic",
              color: "rgba(248,246,235,0.7)",
              display: "flex", alignItems: "center", gap: 8,
            }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--me-orange)" strokeWidth="2" strokeLinecap="square">
                <path d="M3 12h4l3-7 4 14 3-7h4" />
              </svg>
              Macros scale to your hourly carb target
            </div>
          </div>
        )}

        {editing && (
          <div style={{ marginTop: 12, display: "flex", justifyContent: "center" }}>
            <window.AddFoodButton onClick={onAddFood} />
          </div>
        )}

        {editing && isPersonal && (
          <DeleteSection
            confirm={confirmDelete}
            onAsk={onAskDelete}
            onCancel={onCancelDelete}
            onDelete={onDelete}
          />
        )}

        {editing && (
          <div style={{
            marginTop: 12, padding: "10px 12px", borderRadius: 10,
            background: "rgba(247,139,20,0.06)",
            fontFamily: "Apercu, sans-serif", fontSize: 11.5, fontStyle: "italic",
            color: "rgba(248,246,235,0.65)",
            display: "flex", alignItems: "center", gap: 8,
          }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--me-orange)" strokeWidth="2" strokeLinecap="square">
              <path d="M3 12h4l3-7 4 14 3-7h4" />
            </svg>
            During templates are ratio-locked. Quantities scale to your hourly carb target at plan-generation time.
          </div>
        )}
      </div>

      {!editing && <DietTags allergens={formula.allergens || []} excludes={formula.excludes || []} />}
    </div>
  );
}

function DuringReadRow({ item, customFoods }) {
  const food = window.lookupFood(item.foodKey, customFoods);
  const category = food?.category || "solid";
  const isPersonal = !!food?.isPersonal;
  return (
    <div style={{
      borderRadius: 14,
      background: "rgba(248,246,235,0.025)",
      border: "1px solid rgba(248,246,235,0.08)",
      padding: "10px 12px", display: "flex", alignItems: "center", gap: 12,
    }}>
      <window.CategoryChip category={category} isPersonal={isPersonal} size={36} />
      <div style={{
        flex: 1, minWidth: 0,
        fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 15.5,
        color: "var(--me-cream)", lineHeight: 1.2,
      }}>{food?.name || item.raw || "Unknown"}</div>
    </div>
  );
}

function DeleteSection({ confirm, onAsk, onCancel, onDelete }) {
  if (!confirm) {
    return (
      <div style={{ marginTop: 14, display: "flex", justifyContent: "center" }}>
        <button onClick={onAsk} style={{
          background: "transparent", border: "none", cursor: "pointer",
          color: "oklch(0.65 0.16 25)",
          fontFamily: "Apercu, sans-serif", fontSize: 13, fontWeight: 500,
          padding: "10px 14px", textDecoration: "underline", textUnderlineOffset: 3,
        }}>Delete formula</button>
      </div>
    );
  }
  return (
    <div style={{
      marginTop: 14, padding: "14px 16px", borderRadius: 14,
      background: "rgba(220,37,151,0.08)",
      border: "1px solid rgba(220,37,151,0.3)",
      display: "flex", flexDirection: "column", gap: 12,
    }}>
      <div style={{
        fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 15,
        color: "var(--me-cream)",
      }}>Delete this formula?</div>
      <div style={{
        fontFamily: "Apercu, sans-serif", fontSize: 12.5, lineHeight: 1.5,
        color: "rgba(248,246,235,0.7)",
      }}>This removes your personalized formula. The system template stays in your kit.</div>
      <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
        <button onClick={onCancel} style={{
          height: 36, padding: "0 16px", borderRadius: 100,
          background: "transparent", color: "var(--me-cream)",
          border: "1px solid rgba(248,246,235,0.25)",
          cursor: "pointer",
          fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 13,
        }}>Cancel</button>
        <button onClick={onDelete} style={{
          height: 36, padding: "0 18px", borderRadius: 100,
          background: "var(--me-dragonfruit)", color: "var(--me-cream)",
          border: "none", cursor: "pointer",
          fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
        }}>Delete</button>
      </div>
    </div>
  );
}

function DurList({ label, items, mono }) {
  return (
    <div>
      <div style={{
        fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
        letterSpacing: "0.1em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.5)", marginBottom: 6,
      }}>{label}</div>
      <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
        {items.map((it, i) => (
          <span key={i} style={{
            display: "inline-flex", alignItems: "center", height: 22, padding: "0 9px",
            borderRadius: 6, background: "rgba(248,246,235,0.08)",
            color: "var(--me-cream)",
            fontFamily: mono ? "'Apercu Mono', monospace" : "Apercu, sans-serif",
            fontSize: 11.5, fontWeight: 500,
            fontVariantNumeric: mono ? "tabular-nums" : "normal",
          }}>{it}</span>
        ))}
      </div>
    </div>
  );
}

function DietTags({ allergens, excludes }) {
  if (allergens.length === 0 && excludes.length === 0) return null;
  return (
    <div>
      <div style={{
        fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
        letterSpacing: "0.1em", textTransform: "uppercase",
        color: "rgba(248,246,235,0.5)", marginBottom: 8,
      }}>Diet & allergens</div>
      <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
        {allergens.map(a => <window.AllergenTag key={a} label={a} />)}
        {excludes.map(e => <window.ExcludeTag key={e} label={window.DIET_LABELS[e] || e} />)}
      </div>
    </div>
  );
}

Object.assign(window, { DetailScreen });
