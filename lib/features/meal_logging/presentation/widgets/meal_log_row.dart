import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/daily_macros/presentation/widgets/macro_palette.dart'
    show kMacroColorCarbs, kMacroColorFat, kMacroColorProtein;
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';
import 'slot_palette.dart';

/// A single row representing a [MealLog] entry in the daily log list.
///
/// Displays:
/// - A leading photo thumbnail (if [log.photoPath] is set) or a food icon
/// - Bold name with a small coloured slot chip
/// - Calories and compact C/P/F macros in subtitle
///
/// Interaction:
/// - Tapping the row invokes [onEdit] (opens the edit screen).
/// - Swiping end-to-start triggers [onDelete] (soft delete with undo snackbar
///   handled in the parent widget).
/// - A trailing [PopupMenuButton] provides 'Save as Favorite'.
class MealLogRow extends ConsumerWidget {
  const MealLogRow({
    super.key,
    required this.log,
    required this.onDelete,
    required this.onSaveFavorite,
    required this.onEdit,
  });

  final MealLog log;

  /// Called immediately when the dismiss gesture completes (soft delete already
  /// applied; parent shows undo snackbar).
  final VoidCallback onDelete;

  /// Called with the name the user chose for saving (may differ from [log.name]).
  final ValueChanged<String> onSaveFavorite;

  /// Called when the user taps the row to open the edit screen.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor =
        isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant;

    final calories = log.calories;
    final carbsG = log.carbsG;
    final proteinG = log.proteinG;
    final fatG = log.fatG;

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.dragonfruit,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          // Custom flex layout (not ListTile): the name + macros live in an
          // Expanded column so they always get the leftover width and reflow
          // gracefully, while only the menu button is fixed-width trailing.
          // ListTile's title/trailing tug-of-war could starve the title to a
          // few px on narrow phones and overflow.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LeadingPhoto(photoPath: log.photoPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              log.name,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SlotChip(slot: log.slot),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _MacroSummaryLine(
                        calories: calories,
                        carbsG: carbsG,
                        proteinG: proteinG,
                        fatG: fatG,
                        subtitleColor: subtitleColor,
                        textColor:
                            isDark ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_MenuAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _MenuAction.saveFavorite:
                        _showSaveFavoriteDialog(context);
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MenuAction.saveFavorite,
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Save as Favorite'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSaveFavoriteDialog(BuildContext context) {
    final ctrl = TextEditingController(text: log.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Favorite'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              Navigator.of(ctx).pop();
              onSaveFavorite(name.isEmpty ? log.name : name);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { saveFavorite }

/// Displays a small meal photo thumbnail, or a food icon as a fallback.
class _LeadingPhoto extends ConsumerWidget {
  const _LeadingPhoto({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoPath == null || photoPath!.isEmpty) {
      return const CircleAvatar(
        child: Icon(Icons.restaurant_outlined, size: 20),
      );
    }

    final urlAsync = ref.watch(mealPhotoSignedUrlProvider(photoPath));
    return urlAsync.when(
      data: (url) {
        if (url == null) {
          return const CircleAvatar(
            child: Icon(Icons.restaurant_outlined, size: 20),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            url,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const CircleAvatar(
              child: Icon(Icons.restaurant_outlined, size: 20),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const CircleAvatar(
        child: Icon(Icons.restaurant_outlined, size: 20),
      ),
    );
  }
}

/// Small coloured slot chip (Breakfast / Lunch / Dinner / Snack).
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot});

  final MealSlot slot;

  @override
  Widget build(BuildContext context) {
    final color = slotColor(slot);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        slot.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Macro summary line
// ---------------------------------------------------------------------------

/// Single wrapping line: '640 kcal · 72C · 45P · 18F', where the kcal value is
/// bold in the text colour and each macro uses its canonical accent.
///
/// Lives inside an [Expanded] column, so the [RichText] has a bounded width and
/// reflows to a second line rather than overflowing on narrow rows.
class _MacroSummaryLine extends StatelessWidget {
  const _MacroSummaryLine({
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.subtitleColor,
    required this.textColor,
  });

  final int? calories;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final Color subtitleColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];

    final sep = TextSpan(
      text: '  ·  ',
      style: TextStyle(fontSize: 12, color: subtitleColor),
    );

    if (calories != null) {
      spans.add(TextSpan(children: [
        TextSpan(
          text: '$calories',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        TextSpan(
          text: ' kcal',
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
      ]));
    }

    void addMacro(double? value, String suffix, Color color) {
      if (value == null) return;
      if (spans.isNotEmpty) spans.add(sep);
      spans.add(TextSpan(
        text: '${value.toStringAsFixed(0)}$suffix',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ));
    }

    addMacro(carbsG, 'C', kMacroColorCarbs);
    addMacro(proteinG, 'P', kMacroColorProtein);
    addMacro(fatG, 'F', kMacroColorFat);

    if (spans.isEmpty) return const SizedBox.shrink();

    return RichText(text: TextSpan(children: spans));
  }
}
