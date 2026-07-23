import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/daily_macros/presentation/widgets/macro_palette.dart'
    show kMacroColorCarbs, kMacroColorFat, kMacroColorProtein;
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_favorite_match.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../../domain/saved_meal.dart';
import '../providers/meal_log_providers.dart';
import 'slot_palette.dart';

/// A single row representing a [MealLog] entry in the daily log list.
///
/// Displays:
/// - A leading photo thumbnail (if [log.photoPath] is set) or a food icon
/// - Bold name with a small coloured slot chip
/// - Calories and compact C/P/F macros in subtitle
///
/// Interaction (unified card interaction 391e3fdb):
/// - Tapping the row invokes [onEdit] (opens the edit screen).
/// - Swiping in either direction triggers [onDelete] (soft delete with undo
///   snackbar handled in the parent widget).
/// - A one-tap star toggles favorite status (no overflow menu).
class MealLogRow extends ConsumerWidget {
  const MealLogRow({
    super.key,
    required this.log,
    required this.onDelete,
    required this.onEdit,
  });

  final MealLog log;

  /// Called immediately when the dismiss gesture completes (soft delete already
  /// applied; parent shows undo snackbar).
  final VoidCallback onDelete;

  /// Called when the user taps the row to open the edit screen.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = isDark
        ? Colors.white60
        : theme.colorScheme.onSurfaceVariant;

    final calories = log.calories;
    final carbsG = log.carbsG;
    final proteinG = log.proteinG;
    final fatG = log.fatG;

    // Favorite lookup — matched by name + component signature since
    // `saved_meals` has no back-link column to the originating log (item 23).
    final favoritesAsync = ref.watch(savedMealsProvider);
    final favorites = favoritesAsync.asData?.value ?? const <SavedMeal>[];
    final matchedFavorite = findFavoriteMatch(log, favorites);

    // Both directions delete (unified card interaction 391e3fdb).
    // confirmDismiss fires the delete and returns false so the row leaves via
    // the provider rebuild, never a structural dismiss.
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: _deleteBackground(Alignment.centerLeft),
      secondaryBackground: _deleteBackground(Alignment.centerRight),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          // Custom flex layout (not ListTile): the name + macros live in an
          // Expanded column so they always get the leftover width and reflow
          // gracefully, while only the star button is fixed-width trailing.
          // ListTile's title/trailing tug-of-war could starve the title to a
          // few px on narrow phones and overflow.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LeadingPhoto(photoPath: log.photoPath, name: log.name),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                        textColor: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    matchedFavorite != null ? Icons.star : Icons.star_border,
                    size: 20,
                    color: matchedFavorite != null
                        ? AppColors.orange
                        : subtitleColor,
                  ),
                  tooltip: matchedFavorite != null
                      ? 'Remove from favorites'
                      : 'Save as favorite',
                  onPressed: () =>
                      _toggleFavorite(context, ref, matchedFavorite),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Toggles the favorite star: saves [log] as a new favorite when it isn't
  /// currently matched to one, or removes the matched favorite otherwise
  /// (item 23 — one-tap star, reusing the existing `saved_meals` mechanism).
  void _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    SavedMeal? matchedFavorite,
  ) {
    final notifier = ref.read(mealLogControllerProvider.notifier);
    if (matchedFavorite != null) {
      notifier.deleteSavedMeal(matchedFavorite.id);
      MealvanaSnackbar.showInfo(context, 'Removed from favorites');
    } else {
      notifier.saveLogAsFavorite(log);
      MealvanaSnackbar.showSuccess(context, 'Saved as favorite');
    }
  }

  /// Delete-red swipe background, mirrored to whichever side is revealed.
  Widget _deleteBackground(Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.dragonfruit,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
    );
  }
}

/// Displays a small meal photo thumbnail, or a food icon as a fallback.
class _LeadingPhoto extends ConsumerWidget {
  const _LeadingPhoto({required this.photoPath, required this.name});

  final String? photoPath;
  final String name;

  /// Branded circular food icon (matches the food icon on Activity Detail),
  /// used whenever there's no meal photo to show.
  Widget get _fallback =>
      KyleFoodIcon(foodType: mapFoodType(name: name), size: 40);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoPath == null || photoPath!.isEmpty) {
      return _fallback;
    }

    final urlAsync = ref.watch(mealPhotoSignedUrlProvider(photoPath));
    return urlAsync.when(
      data: (url) {
        if (url == null) {
          return _fallback;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            url,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback,
          ),
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => _fallback,
    );
  }
}

/// Small coloured slot chip (Breakfast / Lunch / Dinner / Snack).
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot});

  /// Null when the meal is untagged (slot is optional — build-a-meal
  /// redesign). Renders nothing rather than a placeholder chip so untagged
  /// rows don't look "broken".
  final MealSlot? slot;

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;
    if (slot == null) return const SizedBox.shrink();
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
      spans.add(
        TextSpan(
          children: [
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
          ],
        ),
      );
    }

    void addMacro(double? value, String suffix, Color color) {
      if (value == null) return;
      if (spans.isNotEmpty) spans.add(sep);
      spans.add(
        TextSpan(
          text: '${value.toStringAsFixed(0)}$suffix',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
    }

    addMacro(carbsG, 'C', kMacroColorCarbs);
    addMacro(proteinG, 'P', kMacroColorProtein);
    addMacro(fatG, 'F', kMacroColorFat);

    if (spans.isEmpty) return const SizedBox.shrink();

    return RichText(text: TextSpan(children: spans));
  }
}
