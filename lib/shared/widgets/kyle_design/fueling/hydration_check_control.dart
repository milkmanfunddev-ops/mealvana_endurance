/// Design SSOT component — **Hydration Check**.
///
/// Spec: `docs/ssot/spec/design/components/hydration-check.md` **v1**
/// (RATIFIED Xuan 2026-08-26). Reference rendering
/// `docs/ssot/spec/design/renderings/pre-workout@v2.html` — sizes, opacities
/// and copy are that rendering's, verbatim; the copy register ships as-is.
///
/// The inline urine-check control. Owns its expand state and its
/// presentation; the *write* (the fluid target, the added water row) is the
/// surface's — this control only **emits** (H-5) via [onAnswer] and
/// [onChangeAnswer]. Behaviour authority: hydration v6 *The urine check* as
/// amended by PW-021 (athlete-timed, no live clock — nothing here reads a
/// clock, and nothing here disables itself).
///
/// * `answer = NONE` renders collapsed as a chip (`TO-DO`); tap expands the
///   question in place (H-1) — never navigates.
/// * Tap an answer → [onAnswer] (H-2); the control collapses to the result
///   line with a **Change answer** affordance.
/// * **Change answer** → [onChangeAnswer] (H-3); the surface reverts.
///
/// Existence (sub-2 h suppression, gated suppression — P1) is decided by the
/// surface's assembler: when the check does not exist this widget is not in
/// the tree at all.
///
/// Tokens: ring, drop and status line in `electrolyte` (Q-D8); TO-DO pill,
/// option hover and Change answer in `orange`; text `cream`.
library;

import 'package:flutter/material.dart';

import '../../../../features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import '../../../../features/nutrition_plan/domain/pre_workout_hydration_check.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import 'fueling_glyphs.dart';

class HydrationCheckControl extends StatefulWidget {
  const HydrationCheckControl({
    super.key,
    required this.state,
    required this.onAnswer,
    required this.onChangeAnswer,
    this.initiallyExpanded = false,
  });

  final HydrationCheckViewState state;
  final ValueChanged<HydrationCheckAnswer> onAnswer;
  final VoidCallback onChangeAnswer;
  final bool initiallyExpanded;

  static const Key rootKey = Key('hydration_check');
  static const Key headerKey = Key('hydration_check.header');
  static const Key todoKey = Key('hydration_check.todo');
  static const Key statusKey = Key('hydration_check.status');
  static const Key questionKey = Key('hydration_check.question');
  static const Key bodyKey = Key('hydration_check.body');
  static const Key changeAnswerKey = Key('hydration_check.change_answer');

  /// HIG minimum tap target for the Change answer link.
  static const double changeAnswerMinTapHeight = 44;

  static Key optionKey(HydrationCheckAnswer a) =>
      Key('hydration_check.option.${a.name}');

  @override
  State<HydrationCheckControl> createState() => _HydrationCheckControlState();
}

class _HydrationCheckControlState extends State<HydrationCheckControl> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final answered = widget.state.isAnswered;
    return AnimatedContainer(
      key: HydrationCheckControl.rootKey,
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: answered ? creamAlpha(.14) : electrolyteAlpha(.55),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            key: HydrationCheckControl.headerKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.electrolyte,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const FuelingGlyph(
                    path: FuelingGlyphPaths.drop,
                    size: 16,
                    color: AppColors.electrolyte,
                    strokeWidth: 1.9,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        HydrationCheckCopy.title,
                        style: fuelingDisplayStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        HydrationCheckCopy.subtitle,
                        style: TextStyle(
                          fontFamily: AppTextStyles.apercu,
                          fontSize: 10.5,
                          color: creamAlpha(.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!answered) ...[
                  const SizedBox(width: 11),
                  Container(
                    key: HydrationCheckControl.todoKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.orange),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      HydrationCheckCopy.todo,
                      style: TextStyle(
                        fontFamily: AppTextStyles.apercu,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8.5 * .08,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 11),
                FuelingChevron(
                  expanded: _expanded,
                  size: 13,
                  color: creamAlpha(.6),
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
          if (answered) ...[
            const SizedBox(height: 8),
            Text(
              widget.state.resultLine,
              key: HydrationCheckControl.statusKey,
              style: const TextStyle(
                fontFamily: AppTextStyles.apercu,
                fontSize: 10.5,
                letterSpacing: 10.5 * .03,
                color: AppColors.electrolyte,
              ),
            ),
          ],
          if (_expanded && !answered) _question(),
          if (_expanded && answered) _result(),
        ],
      ),
    );
  }

  Widget _question() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          HydrationCheckCopy.question,
          key: HydrationCheckControl.questionKey,
          style: fuelingDisplayStyle(fontSize: 15, height: 1.25),
        ),
        const SizedBox(height: 6),
        Text(HydrationCheckCopy.timing, style: _dimBody),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _option(
                HydrationCheckCopy.optionPale,
                HydrationCheckAnswer.pale,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _option(
                HydrationCheckCopy.optionDark,
                HydrationCheckAnswer.dark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _option(
                HydrationCheckCopy.optionNotYet,
                HydrationCheckAnswer.notYet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _option(
                HydrationCheckCopy.optionNotSure,
                HydrationCheckAnswer.notSure,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(HydrationCheckCopy.caveat, style: _dimBody),
      ],
    );
  }

  Widget _result() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          widget.state.resultBody,
          key: HydrationCheckControl.bodyKey,
          style: TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 12,
            height: 1.5,
            color: creamAlpha(.75),
          ),
        ),
        // "Change answer" — the text sits 8 px below the body as in the
        // rendering, but the HIT TARGET is a 44 pt band (Apple HIG minimum)
        // so a finger tap wins the arena against the scroll view (ops bug
        // 2026-08-26-hydration-check-change-answer-tap-target-too-small).
        GestureDetector(
          key: HydrationCheckControl.changeAnswerKey,
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _expanded = true);
            widget.onChangeAnswer();
          },
          child: Container(
            constraints: const BoxConstraints(
              minHeight: HydrationCheckControl.changeAnswerMinTapHeight,
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(top: 8, right: 24),
            child: const Text(
              HydrationCheckCopy.changeAnswer,
              style: TextStyle(
                fontFamily: AppTextStyles.apercu,
                fontSize: 12,
                color: AppColors.orange,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle get _dimBody => TextStyle(
    fontFamily: AppTextStyles.apercu,
    fontSize: 11,
    height: 1.45,
    color: creamAlpha(.55),
  );

  Widget _option(String label, HydrationCheckAnswer answer) {
    return GestureDetector(
      key: HydrationCheckControl.optionKey(answer),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _expanded = true);
        widget.onAnswer(answer);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: creamAlpha(.35)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 12.5,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}
