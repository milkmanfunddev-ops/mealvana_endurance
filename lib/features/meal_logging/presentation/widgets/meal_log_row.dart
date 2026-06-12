import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/daily_macros/presentation/widgets/today_hero_card.dart'
    show kMacroColorCarbs, kMacroColorFat, kMacroColorProtein;
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../providers/meal_log_providers.dart';

Color _slotColor(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return const Color(0xFFFF9500);
    case MealSlot.lunch:
      return const Color(0xFF00C896);
    case MealSlot.dinner:
      return const Color(0xFF6B4FA0);
    case MealSlot.snack:
      return const Color(0xFFFF2D55);
  }
}

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
          color: const Color(0xFFFF2D55), // dragonfruit
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: _LeadingPhoto(photoPath: log.photoPath),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    log.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _slotColor(log.slot).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.slot.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _slotColor(log.slot),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Right-aligned macro column
                _MacroTrailing(
                  calories: calories,
                  carbsG: carbsG,
                  proteinG: proteinG,
                  fatG: fatG,
                  subtitleColor: subtitleColor,
                  textColor: isDark
                      ? Colors.white
                      : theme.colorScheme.onSurface,
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

// ---------------------------------------------------------------------------
// Compact right-aligned macro trailing column
// ---------------------------------------------------------------------------

/// Right-aligned column showing kcal bold on top and a coloured C/P/F line below.
///
/// Imports macro colour constants from [today_hero_card.dart] so the colours
/// stay in sync across the app.
class _MacroTrailing extends StatelessWidget {
  const _MacroTrailing({
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
    final hasKcal = calories != null;
    final hasMacros = carbsG != null || proteinG != null || fatG != null;

    if (!hasKcal && !hasMacros) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasKcal)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$calories',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        if (hasMacros) ...[
          const SizedBox(height: 2),
          _CompactMacroLine(
            carbsG: carbsG,
            proteinG: proteinG,
            fatG: fatG,
          ),
        ],
      ],
    );
  }
}

/// Coloured '38C · 26P · 13F' text where each letter+number uses its macro colour.
class _CompactMacroLine extends StatelessWidget {
  const _CompactMacroLine({
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
  });

  final double? carbsG;
  final double? proteinG;
  final double? fatG;

  @override
  Widget build(BuildContext context) {
    const sep = TextSpan(
      text: ' · ',
      style: TextStyle(fontSize: 11, color: Colors.grey),
    );

    final spans = <TextSpan>[];

    if (carbsG != null) {
      spans.add(TextSpan(
        text: '${carbsG!.toStringAsFixed(0)}C',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kMacroColorCarbs,
        ),
      ));
    }
    if (proteinG != null) {
      if (spans.isNotEmpty) spans.add(sep);
      spans.add(TextSpan(
        text: '${proteinG!.toStringAsFixed(0)}P',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kMacroColorProtein,
        ),
      ));
    }
    if (fatG != null) {
      if (spans.isNotEmpty) spans.add(sep);
      spans.add(TextSpan(
        text: '${fatG!.toStringAsFixed(0)}F',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kMacroColorFat,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
