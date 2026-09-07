/// Design SSOT component — **Selectable Chip Grid**.
///
/// Spec: `docs/ssot/spec/design/components/selectable-chip-grid.md` **v1**
/// (PROPOSED Lee 2026-09-03, awaiting Xuan).
///
/// A wrapping grid of toggle chips the athlete ticks in any combination, with
/// an optional trailing `+` chip that opens an inline text entry for an item
/// the grid did not offer. Composed by the pantry card (plan Phase 7) and any
/// future multi-pick surface; the host owns [items] and [selected] and hears
/// every change.
///
/// Contracts held here:
/// * **SCG-1** — toggle, never radio; [onChanged] carries the whole new set.
/// * **SCG-2** — the `+` chip is last and is not an item; submitting
///   non-empty text calls [onAddCustom] and closes the entry, the host adds
///   the item.
/// * **SCG-3** — `enabled = false` greys every chip, hides `+`, ignores taps;
///   selected chips keep their check.
/// * **SCG-4** — no selection cap.
/// * **SCG-L1/L2/L3** — wrap never scroll; the Vana choice-chip form with a
///   leading check when selected; the entry opens in the wrap's flow.
///
/// Tokens: the electrolyte selection accent (chosen = solid fill, resting =
/// outline over a faint wash) exactly as Vana's single-pick chip; neutral at
/// low alpha when disabled. No meaning-bound colour beyond "chosen".
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

class SelectableChipGrid extends StatefulWidget {
  const SelectableChipGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.allowCustom = false,
    this.onAddCustom,
    this.enabled = true,
    this.customHint = '',
    this.addLabel = '+',
    this.submitLabel = '',
  });

  /// Host-owned, ordered, unique labels (SCG-5).
  final List<String> items;

  /// Host-owned selection — a subset of [items].
  final Set<String> selected;

  /// The full set after a toggle (SCG-1).
  final ValueChanged<Set<String>> onChanged;

  /// Show the trailing `+` chip (SCG-2). Needs [onAddCustom].
  final bool allowCustom;

  /// A non-empty custom entry was submitted; the host appends (and by
  /// convention selects) it.
  final ValueChanged<String>? onAddCustom;

  /// `false` once the host committed the selection (SCG-3).
  final bool enabled;

  /// Placeholder for the inline entry — the host's copy.
  final String customHint;

  /// The trailing chip's label; `+` by default.
  final String addLabel;

  /// Label for the entry's submit affordance; when empty an icon is used.
  final String submitLabel;

  @override
  State<SelectableChipGrid> createState() => _SelectableChipGridState();
}

class _SelectableChipGridState extends State<SelectableChipGrid> {
  bool _entryOpen = false;
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(SelectableChipGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SCG-3: disabling closes any open entry.
    if (!widget.enabled && _entryOpen) _entryOpen = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String label) {
    if (!widget.enabled) return;
    final next = Set<String>.of(widget.selected);
    if (!next.remove(label)) next.add(label);
    widget.onChanged(next);
  }

  void _submit() {
    final text = _controller.text.trim();
    setState(() => _entryOpen = false);
    _controller.clear();
    if (text.isEmpty) return;
    widget.onAddCustom?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final showAdd =
        widget.allowCustom && widget.enabled && widget.onAddCustom != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final label in widget.items)
              _GridChip(
                key: ValueKey('selectable_chip_$label'),
                label: label,
                selected: widget.selected.contains(label),
                enabled: widget.enabled,
                onTap: () => _toggle(label),
              ),
            if (showAdd && !_entryOpen)
              _GridChip(
                key: const ValueKey('selectable_chip_add'),
                label: widget.addLabel,
                selected: false,
                enabled: true,
                emphasized: true,
                onTap: () => setState(() => _entryOpen = true),
              ),
          ],
        ),
        // SCG-L3: the entry opens in the flow, full width.
        if (showAdd && _entryOpen) ...[
          const SizedBox(height: AppSpacing.xs),
          _CustomEntry(
            controller: _controller,
            hint: widget.customHint,
            submitLabel: widget.submitLabel,
            onSubmit: _submit,
            onDismiss: () {
              _controller.clear();
              setState(() => _entryOpen = false);
            },
          ),
        ],
      ],
    );
  }
}

/// One toggle chip — the Vana choice-chip form (SCG-L2) with a leading check
/// when selected.
class _GridChip extends StatelessWidget {
  const _GridChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final neutral = isDark ? AppColors.cream : AppColors.blackberry;

    final Color background;
    final Color border;
    final Color foreground;
    final FontWeight weight;

    if (!enabled) {
      background = Colors.transparent;
      border = neutral.withValues(alpha: 0.15);
      foreground = neutral.withValues(alpha: selected ? 0.5 : 0.3);
      weight = selected ? FontWeight.w600 : FontWeight.w500;
    } else if (selected) {
      background = accent;
      border = accent;
      foreground = AppColors.blackberry;
      weight = FontWeight.w700;
    } else {
      background = accent.withValues(alpha: isDark ? 0.1 : 0.07);
      border = accent.withValues(alpha: emphasized ? 1 : 0.6);
      foreground = accent;
      weight = emphasized ? FontWeight.w700 : FontWeight.w500;
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(Icons.check, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          // SCG-L1: a long label ellipsises rather than widening past the
          // host; the Flexible lets the Wrap clamp the chip to its width.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: foreground,
                fontWeight: weight,
              ),
            ),
          ),
        ],
      ),
    );

    if (!enabled) return Semantics(selected: selected, child: chip);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      ),
    );
  }
}

/// The inline single-line entry that replaces the `+` chip (SCG-2).
class _CustomEntry extends StatelessWidget {
  const _CustomEntry({
    required this.controller,
    required this.hint,
    required this.submitLabel,
    required this.onSubmit,
    required this.onDismiss,
  });

  final TextEditingController controller;
  final String hint;
  final String submitLabel;
  final VoidCallback onSubmit;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final neutral = isDark ? AppColors.cream : AppColors.blackberry;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 2, AppSpacing.xxs, 2),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('selectable_chip_entry'),
              controller: controller,
              autofocus: true,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: AppTextStyles.bodySmall.copyWith(color: neutral),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: neutral.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('selectable_chip_dismiss'),
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              size: 16,
              color: neutral.withValues(alpha: 0.6),
            ),
          ),
          GestureDetector(
            key: const ValueKey('selectable_chip_submit'),
            onTap: onSubmit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: submitLabel.isEmpty
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.blackberry,
                    )
                  : Text(
                      submitLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.blackberry,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
