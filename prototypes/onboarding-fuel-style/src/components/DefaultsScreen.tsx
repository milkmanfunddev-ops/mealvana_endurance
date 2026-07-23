import { useMemo, useState } from 'react';
import {
  DEFAULT_IDS,
  MealTemplate,
  Phase,
  PHASE_LABEL,
  TEMPLATES_BY_PHASE,
} from '../data/templates';
import { MealSwapSheet } from './MealSwapSheet';

const css: Record<string, React.CSSProperties> = {
  page: {
    flex: 1,
    minHeight: 0,
    background: 'var(--me-bg-dark)',
    color: 'var(--me-fg-on-dark)',
    display: 'flex',
    flexDirection: 'column',
    position: 'relative',
  },
  scroll: {
    flex: 1,
    overflowY: 'auto',
    padding: '60px 20px 12px',
  },
  progressRow: {
    display: 'flex',
    gap: 6,
    marginBottom: 24,
  },
  progressSeg: {
    flex: 1,
    height: 4,
    borderRadius: 2,
    background: 'rgba(248, 246, 235, 0.18)',
  },
  progressSegActive: { background: 'var(--me-orange)' },
  title: {
    fontFamily: 'var(--me-font-display)',
    fontWeight: 700,
    fontSize: 28,
    lineHeight: 1.1,
    color: 'var(--me-orange)',
    margin: 0,
  },
  subtitle: {
    fontFamily: 'var(--me-font-body)',
    fontSize: 14,
    lineHeight: 1.45,
    color: 'var(--me-fg-on-dark-muted)',
    margin: '8px 0 22px',
  },
  cardList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
  },
  card: {
    display: 'flex',
    flexDirection: 'column',
    padding: 16,
    background: 'var(--me-surface-card-dark)',
    border: '1px solid rgba(248, 246, 235, 0.10)',
    borderRadius: 'var(--me-radius-lg)',
    textAlign: 'left',
    width: '100%',
    transition:
      'border-color var(--me-duration-base) var(--me-ease-out), transform var(--me-duration-fast) var(--me-ease-out)',
  },
  body: {
    display: 'flex',
    flexDirection: 'column',
    gap: 4,
  },
  phaseRow: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 8,
  },
  phaseLabel: {
    fontFamily: 'var(--me-font-mono)',
    fontSize: 10,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: 'var(--me-orange)',
    margin: 0,
  },
  timing: {
    fontFamily: 'var(--me-font-mono)',
    fontSize: 10,
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    color: 'var(--me-fg-on-dark-muted)',
  },
  name: {
    fontFamily: 'var(--me-font-display)',
    fontWeight: 700,
    fontSize: 18,
    color: 'var(--me-cream)',
    margin: '2px 0 2px',
  },
  ingredients: {
    fontFamily: 'var(--me-font-body)',
    fontSize: 13,
    color: 'var(--me-fg-on-dark-muted)',
    margin: 0,
    lineHeight: 1.4,
  },
  swapRow: {
    marginTop: 8,
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  macroNote: {
    fontFamily: 'var(--me-font-mono)',
    fontSize: 11,
    color: 'var(--me-fg-on-dark-muted)',
  },
  swap: {
    fontFamily: 'var(--me-font-body)',
    fontWeight: 600,
    fontSize: 13,
    color: 'var(--me-orange)',
    padding: '6px 12px',
    borderRadius: 'var(--me-radius-pill)',
    background: 'rgba(247, 139, 20, 0.12)',
    border: '1px solid rgba(247, 139, 20, 0.30)',
  },
  footer: {
    padding: '12px 20px 28px',
    background:
      'linear-gradient(180deg, rgba(56,22,51,0) 0%, var(--me-bg-dark) 30%)',
  },
  cta: {
    width: '100%',
    height: 56,
    borderRadius: 'var(--me-radius-pill)',
    background: 'var(--me-orange)',
    color: 'var(--me-blackberry)',
    fontFamily: 'var(--me-font-body)',
    fontWeight: 700,
    fontSize: 17,
    letterSpacing: 0.2,
    boxShadow: 'var(--me-shadow-glow)',
  },
  resetRow: {
    marginTop: 14,
    display: 'flex',
    justifyContent: 'center',
  },
  resetBtn: {
    fontFamily: 'var(--me-font-body)',
    fontSize: 12,
    color: 'var(--me-fg-on-dark-muted)',
    padding: '6px 10px',
    textDecoration: 'underline',
    textUnderlineOffset: 3,
  },
};

const PHASES: Phase[] = ['before', 'during', 'after'];

export function DefaultsScreen() {
  const [selectedIds, setSelectedIds] = useState<Record<Phase, string>>(() => ({
    ...DEFAULT_IDS,
  }));
  const [openPhase, setOpenPhase] = useState<Phase | null>(null);

  const selectedTemplates = useMemo<Record<Phase, MealTemplate>>(() => {
    return PHASES.reduce(
      (acc, phase) => {
        const found = TEMPLATES_BY_PHASE[phase].find(
          t => t.id === selectedIds[phase],
        )!;
        acc[phase] = found;
        return acc;
      },
      {} as Record<Phase, MealTemplate>,
    );
  }, [selectedIds]);

  const hasChanges = PHASES.some(p => selectedIds[p] !== DEFAULT_IDS[p]);

  return (
    <div style={css.page}>
      <div style={css.scroll}>
        <div style={css.progressRow}>
          <span style={{ ...css.progressSeg, ...css.progressSegActive }} />
          <span style={{ ...css.progressSeg, ...css.progressSegActive }} />
          <span style={{ ...css.progressSeg, ...css.progressSegActive }} />
          <span style={css.progressSeg} />
        </div>

        <h1 style={css.title}>Your default fuel plan</h1>
        <p style={css.subtitle}>
          We've picked a normal pre, during, and post-workout formula. Tap
          any meal to swap it. You can change anything later in Settings.
        </p>

        <div style={css.cardList}>
          {PHASES.map(phase => {
            const t = selectedTemplates[phase];
            return (
              <button
                key={phase}
                type="button"
                style={css.card}
                onClick={() => setOpenPhase(phase)}
              >
                <div style={css.body}>
                  <div style={css.phaseRow}>
                    <p style={css.phaseLabel}>{PHASE_LABEL[phase]}</p>
                    <span style={css.timing}>{t.timingNote}</span>
                  </div>
                  <h2 style={css.name}>{t.name}</h2>
                  <p style={css.ingredients}>{t.ingredients.join(' · ')}</p>
                  <div style={css.swapRow}>
                    <span style={css.macroNote}>{t.macroNote}</span>
                    <span style={css.swap}>Swap</span>
                  </div>
                </div>
              </button>
            );
          })}
        </div>

        {hasChanges && (
          <div style={css.resetRow}>
            <button
              type="button"
              style={css.resetBtn}
              onClick={() => setSelectedIds({ ...DEFAULT_IDS })}
            >
              Reset to Mealvana defaults
            </button>
          </div>
        )}
      </div>

      <div style={css.footer}>
        <button
          type="button"
          style={css.cta}
          onClick={() => {
            const summary = PHASES.map(
              p =>
                `${PHASE_LABEL[p]}: ${selectedTemplates[p].name} (${selectedIds[p]})`,
            ).join('\n');
            window.alert(`Saved fuel plan:\n\n${summary}`);
          }}
        >
          Looks good — let's start
        </button>
      </div>

      {openPhase && (
        <MealSwapSheet
          phase={openPhase}
          currentId={selectedIds[openPhase]}
          onClose={() => setOpenPhase(null)}
          onPick={t => {
            setSelectedIds(prev => ({ ...prev, [openPhase]: t.id }));
            setOpenPhase(null);
          }}
        />
      )}
    </div>
  );
}
