/// Design SSOT component — **Carb Slot Card** (loading-day timeline group).
///
/// Spec: `docs/ssot/spec/design/components/carb-slot-card.md` **v1**
/// (RATIFIED Xuan 2026-09-25, extraction from prototype v21). Reference
/// rendering: prototype v22 (`fuel-timeline-standalone.html`, bundle sha
/// `f1c232d958a98bfe`).
///
/// Contracts held here (states table + SC-1..SC-4):
/// * `EMPTY` — header only (name · clock · `0 / <target> g`), dashed
///   treatment. `FILLED` — header figure + ONE summary line. `PEEK` —
///   read-only receipt (name · grams per row) + `Edit in <slot> ›`; no
///   steppers, no remove.
/// * SC-1: the WHOLE card surface opens the slot interior page — the card is
///   a gauge and a door. SC-2: the chevron toggles PEEK only, never
///   navigates. SC-3: `Edit in <slot> ›` goes where SC-1 goes. SC-4:
///   no swipe actions, no inline add, no idea rows.
/// * Eaten may EXCEED target — no clamp, no warning state. Receipt rows sum
///   to the header figure exactly (the assembler guarantees it; a mismatch
///   is a red).
/// * Day variants are surface-driven: FUTURE renders EMPTY-form at that
///   day's targets with no logging affordance; PAST renders summaries only.
///
/// Tokens (`tokens.md`): eaten figure `orange` (Q-D3 intake side), text
/// `cream`, dashed/solid borders `cream` alphas — hairlines do the work.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

class CarbSlotCard extends StatelessWidget {
  const CarbSlotCard({
    super.key,
    required this.label,
    required this.clockStr,
    required this.headerFigure,
    required this.isEmpty,
    required this.summaryLine,
    required this.receiptRows,
    required this.peekOpen,
    required this.onOpen,
    required this.onTogglePeek,
    this.interactive = true,
  });

  final String label;
  final String clockStr;

  /// `124 / 136 g`.
  final String headerFigure;
  final bool isEmpty;
  final String summaryLine;

  /// (name, grams-string) pairs; shown only in PEEK.
  final List<(String, String)> receiptRows;
  final bool peekOpen;

  /// SC-1/SC-3 destination (the slot interior page).
  final VoidCallback onOpen;

  /// SC-2.
  final VoidCallback onTogglePeek;

  /// False on non-today variants: the door stays (page opens
  /// read-only-in-effect) but no affordance is implied.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final cream = AppColors.cream;
    final border = isEmpty
        ? Border.all(color: cream.withValues(alpha: 0.22))
        : Border.all(color: cream.withValues(alpha: 0.12));
    return Semantics(
      button: true,
      label: '$label, $headerFigure',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // SC-1: the whole surface.
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isEmpty ? 0.02 : 0.045),
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: cream.withValues(alpha: 0.7),
                        ),
                        children: [
                          TextSpan(
                            text: '  $clockStr',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                              color: cream.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    headerFigure,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isEmpty
                          ? cream.withValues(alpha: 0.45)
                          : AppColors.orange,
                    ),
                  ),
                  if (!isEmpty)
                    Semantics(
                      button: true,
                      label: peekOpen ? 'Hide items' : 'Show items',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTogglePeek, // SC-2: peek only.
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: AnimatedRotation(
                            turns: peekOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: cream.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!isEmpty && !peekOpen) ...[
                const SizedBox(height: 5),
                Text(
                  summaryLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cream.withValues(alpha: 0.85),
                  ),
                ),
              ],
              if (!isEmpty && peekOpen) ...[
                const SizedBox(height: 7),
                for (final (name, grams) in receiptRows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: cream.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Text(
                          grams,
                          style: TextStyle(
                            fontSize: 12,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: cream.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (interactive)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Edit in $label ›', // SC-3: same door as SC-1.
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
