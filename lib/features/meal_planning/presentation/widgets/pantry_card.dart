import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/inputs/selectable_chip_grid.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';
import 'vana_tag.dart';

/// `pantry` part (plan Phase 7): "What's in the house?" over a
/// [SelectableChipGrid] seeded from the part's items, then "Use these".
/// The card owns the ticked set until the athlete commits; after that it
/// reads as spent (the grid disables, the button becomes the used line).
/// A photo-detected pantry carries a small "from your photo" tag, and a
/// [onScanFridge] host offers a "Scan my fridge" pill beside the title —
/// the photo flow is the primary way through this card, not a menu three
/// taps deep in the composer.
class PantryCard extends ConsumerStatefulWidget {
  const PantryCard({
    super.key,
    required this.part,
    this.onUse,
    this.onScanFridge,
  });

  final VanaPantryPart part;

  /// The ticked names, in grid order; `null` renders the card read-only.
  final ValueChanged<List<String>>? onUse;

  /// Open the camera to scan a fridge/pantry photo (`pantry_photo` flow).
  /// Hidden once the card is used, like every other control.
  final VoidCallback? onScanFridge;

  @override
  ConsumerState<PantryCard> createState() => _PantryCardState();
}

class _PantryCardState extends ConsumerState<PantryCard> {
  late List<String> _items;
  late Set<String> _selected;
  bool _used = false;
  int _usedCount = 0;

  @override
  void initState() {
    super.initState();
    _items = [for (final item in widget.part.items) item.name];
    _selected = widget.part.selectedNames.toSet();
  }

  void _addCustom(String text) {
    // SCG-5: a custom entry matching an existing item (case-insensitive)
    // ticks that item instead of adding a twin.
    final existing = _items.cast<String?>().firstWhere(
      (i) => i!.toLowerCase() == text.toLowerCase(),
      orElse: () => null,
    );
    setState(() {
      if (existing == null) _items = [..._items, text];
      _selected = {..._selected, existing ?? text};
    });
  }

  void _use() {
    final names = [
      for (final item in _items)
        if (_selected.contains(item)) item,
    ];
    setState(() {
      _used = true;
      _usedCount = names.length;
    });
    widget.onUse?.call(names);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final enabled = !_used && widget.onUse != null;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

    return Container(
      key: const ValueKey('meal_planning.pantry_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.part.title ??
                      content.getValue(ContentKeys.mpPantryTitle),
                  key: const ValueKey('meal_planning.pantry_title'),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.part.origin == PantryOrigin.photo) ...[
                const SizedBox(width: AppSpacing.xs),
                VanaTag(
                  key: const ValueKey('meal_planning.pantry_from_photo'),
                  label: content.getValue(ContentKeys.mpPantryFromPhoto),
                ),
              ],
              if (widget.onScanFridge != null && !_used) ...[
                const SizedBox(width: AppSpacing.xs),
                GestureDetector(
                  key: const ValueKey('meal_planning.pantry_scan'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onScanFridge,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.14 : 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          content.getValue(ContentKeys.mpPantryScanFridge),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableChipGrid(
            items: _items,
            selected: _selected,
            enabled: enabled,
            allowCustom: widget.part.allowCustom,
            onAddCustom: _addCustom,
            customHint: content.getValue(ContentKeys.mpPantryAddHint),
            submitLabel: content.getValue(ContentKeys.mpChipGridAdd),
            onChanged: (next) => setState(() => _selected = next),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_used)
            Text(
              ContentKeys.format(content.getValue(ContentKeys.mpPantryUsed), {
                'n': _usedCount,
              }),
              key: const ValueKey('meal_planning.pantry_used'),
              style: AppTextStyles.bodySmall.copyWith(
                color: secondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            KylePrimaryButton(
              key: const ValueKey('meal_planning.pantry_use'),
              text: content.getValue(ContentKeys.mpPantryUseThese),
              height: 44,
              onPressed: enabled ? _use : null,
            ),
        ],
      ),
    );
  }
}
