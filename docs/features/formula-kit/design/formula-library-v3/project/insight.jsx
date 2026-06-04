// Formula Kit V3 — Coach Insight panel (edit state only).
// Tap to generate a short, athlete-to-athlete insight about the current draft.
// Uses window.claude.complete so the copy reflects the actual macros + components live.

const { useState: useStateI, useRef: useRefI } = React;

function buildInsightPrompt({ phase, formula, items, macros, customFoods }) {
  const isBefore = phase === "before";

  const componentLabels = items.map(it => {
    const food = window.lookupFood(it.foodKey, customFoods);
    if (!food) return it.raw || "unknown";
    return isBefore
      ? window.itemLabel(it, { customFoods })
      : food.name;
  });

  const subPhaseLabel = ({
    meal:   "a meal eaten 1.5–3 h before exercise",
    snack:  "a snack eaten 30–90 min before exercise",
    top_up: "a top-up eaten under 30 min before exercise",
  })[formula.sub_phase] || "a pre-workout fueling option";

  const duringContext = formula.foodForm
    ? `a during-workout option, food form: ${formula.foodForm}${formula.ratio ? `, carb ratio ${formula.ratio}` : ""}, durations: ${(formula.durations || []).join(", ")}`
    : "a during-workout fueling option";

  const macroLine = isBefore
    ? `Computed macros: ${macros.carbs}g carbs, ${macros.protein}g protein, ${macros.fat}g fat, ${macros.sodium}mg sodium, ${macros.fluid}ml fluid.`
    : "(Macros are not absolute for during-workout templates — they scale to the athlete's hourly carb target at plan-generation time.)";

  return [
    "You are a Mealvana Endurance fueling coach. The athlete is customizing a personal formula based on the system template below.",
    "",
    `Source template: "${formula.sourceName || formula.name}".`,
    `Context: ${isBefore ? subPhaseLabel : duringContext}.`,
    `Athlete's digestion preference: ${formula.digestion || "n/a"}.`,
    "",
    "Current components in the draft:",
    ...componentLabels.map(c => `- ${c}`),
    "",
    macroLine,
    "",
    "Write ONE short coach insight, 15–28 words, athlete-to-athlete tone. Be direct. Call out genuine gaps or strengths — never both. If the formula is well-balanced for the context, say so plainly. If sodium is light for the duration/intensity, suggest a specific fix (e.g., add a pinch of salt, swap to a sports drink, add an electrolyte tablet). If carbs are low/high for the timing, say so. NEVER use emoji. NEVER use exclamation points. NEVER hedge with 'consider' twice. Output ONLY the insight sentence — no preamble, no quotes, no markdown.",
  ].join("\n");
}

function InsightPanel({ phase, formula, items, macros, customFoods }) {
  const [open, setOpen] = useStateI(false);
  const [loading, setLoading] = useStateI(false);
  const [text, setText] = useStateI(null);
  const [err, setErr] = useStateI(null);
  // Cache key — regenerate if components or macros change
  const sigRef = useRefI("");

  const sig = JSON.stringify({
    items: items.map(it => [it.foodKey, it.qty]),
    macros,
  });

  const fetchInsight = async () => {
    setLoading(true);
    setErr(null);
    try {
      const prompt = buildInsightPrompt({ phase, formula, items, macros, customFoods });
      const reply = await window.claude.complete(prompt);
      const cleaned = (reply || "").trim().replace(/^["'`]+|["'`]+$/g, "");
      sigRef.current = sig;
      setText(cleaned || "No insight available right now.");
    } catch (e) {
      setErr("Couldn't generate insight. Tap to retry.");
    } finally {
      setLoading(false);
    }
  };

  const onToggle = async () => {
    if (open) {
      setOpen(false);
      return;
    }
    setOpen(true);
    if (!text || sigRef.current !== sig) {
      await fetchInsight();
    }
  };

  const onRefresh = async (e) => {
    e.stopPropagation();
    await fetchInsight();
  };

  return (
    <div style={{
      borderRadius: 14,
      border: `1px solid ${open ? "rgba(28,249,207,0.35)" : "rgba(248,246,235,0.12)"}`,
      background: open ? "rgba(28,249,207,0.06)" : "rgba(248,246,235,0.025)",
      overflow: "hidden",
      transition: "background-color 200ms, border-color 200ms",
    }}>
      <button onClick={onToggle} style={{
        width: "100%", padding: "12px 14px",
        background: "transparent", border: "none", cursor: "pointer",
        display: "flex", alignItems: "center", gap: 12, textAlign: "left",
      }}>
        <div style={{
          width: 32, height: 32, borderRadius: "50%",
          background: "var(--me-electrolyte)", color: "var(--me-blackberry)",
          display: "flex", alignItems: "center", justifyContent: "center",
          flex: "0 0 auto",
        }}>
          <SparkleIcon size={16} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 14,
            color: "var(--me-cream)", lineHeight: 1.2,
          }}>Coach insight</div>
          <div style={{
            marginTop: 2,
            fontFamily: "Apercu, sans-serif", fontSize: 11.5,
            color: "rgba(248,246,235,0.6)", lineHeight: 1.3,
          }}>
            {open
              ? (loading ? "Reading your formula…" : "Based on your current components")
              : "Get a quick read on this formula"}
          </div>
        </div>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
             stroke="rgba(248,246,235,0.6)" strokeWidth="2.4" strokeLinecap="square"
             style={{
               flex: "0 0 auto",
               transform: open ? "rotate(180deg)" : "rotate(0deg)",
               transition: "transform 200ms cubic-bezier(0.2,0.8,0.2,1)",
             }}>
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {open && (
        <div style={{
          padding: "0 14px 14px",
          display: "flex", flexDirection: "column", gap: 10,
        }}>
          {loading ? (
            <InsightSkeleton />
          ) : err ? (
            <div style={{
              fontFamily: "Apercu, sans-serif", fontSize: 13, lineHeight: 1.45,
              color: "var(--me-dragonfruit)",
            }}>{err}</div>
          ) : text ? (
            <>
              <div style={{
                fontFamily: "Compadre, Georgia, serif", fontSize: 16.5, lineHeight: 1.4,
                color: "var(--me-cream)",
              }}>{text}</div>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div style={{
                  fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
                  letterSpacing: "0.08em", textTransform: "uppercase",
                  color: "rgba(248,246,235,0.45)",
                }}>{sigRef.current === sig ? "Up to date" : "Outdated — refresh"}</div>
                <button onClick={onRefresh} style={{
                  background: "transparent", border: "none", cursor: "pointer",
                  color: "var(--me-electrolyte)",
                  fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
                  display: "inline-flex", alignItems: "center", gap: 6,
                  padding: "4px 6px",
                }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5" />
                    <path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5" />
                  </svg>
                  Refresh
                </button>
              </div>
            </>
          ) : null}
        </div>
      )}
    </div>
  );
}

function SparkleIcon({ size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
         stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M5.6 18.4l2.8-2.8M15.6 8.4l2.8-2.8" />
    </svg>
  );
}

function InsightSkeleton() {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <SkelLine width="92%" />
      <SkelLine width="76%" />
    </div>
  );
}
function SkelLine({ width }) {
  return (
    <div style={{
      height: 14, width, borderRadius: 6,
      background: "linear-gradient(90deg, rgba(248,246,235,0.06), rgba(248,246,235,0.18), rgba(248,246,235,0.06))",
      backgroundSize: "200% 100%",
      animation: "fk-shimmer 1.3s ease-in-out infinite",
    }} />
  );
}

Object.assign(window, { InsightPanel });
