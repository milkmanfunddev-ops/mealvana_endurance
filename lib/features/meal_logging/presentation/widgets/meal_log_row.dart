import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// - Calories and compact C/P/F macro text
/// - A trailing [PopupMenuButton] for Delete and Save as Favorite
class MealLogRow extends ConsumerWidget {
  const MealLogRow({
    super.key,
    required this.log,
    required this.onDelete,
    required this.onSaveFavorite,
  });

  final MealLog log;
  final VoidCallback onDelete;

  /// Called with the name the user chose for saving (may differ from [log.name]).
  final ValueChanged<String> onSaveFavorite;

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

    final macroText = [
      if (carbsG != null) 'C ${carbsG.toStringAsFixed(0)}g',
      if (proteinG != null) 'P ${proteinG.toStringAsFixed(0)}g',
      if (fatG != null) 'F ${fatG.toStringAsFixed(0)}g',
    ].join('  ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
        subtitle: Text(
          [
            if (calories != null) '$calories kcal',
            if (macroText.isNotEmpty) macroText,
          ].join('  ·  '),
          style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_MenuAction>(
          onSelected: (action) {
            switch (action) {
              case _MenuAction.delete:
                onDelete();
                break;
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
            PopupMenuItem(
              value: _MenuAction.delete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
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

enum _MenuAction { delete, saveFavorite }

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
