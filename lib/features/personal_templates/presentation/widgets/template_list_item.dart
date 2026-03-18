import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/personal_template.dart';

/// Reusable template card widget for displaying a personal template
class TemplateListItem extends StatelessWidget {
  const TemplateListItem({
    super.key,
    required this.template,
    this.onTap,
    this.onMorePressed,
    this.showOverflowMenu = false,
  });

  final PersonalTemplate template;
  final VoidCallback? onTap;
  final VoidCallback? onMorePressed;
  final bool showOverflowMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Sport icon
            _buildSportIcon(context),
            const SizedBox(width: AppSpacing.md),
            // Template details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _buildSubtitle(context),
                  const SizedBox(height: 2),
                  _buildMacroLine(context),
                ],
              ),
            ),
            // Overflow menu or arrow
            if (showOverflowMenu && onMorePressed != null)
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                onPressed: onMorePressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportIcon(BuildContext context) {
    String emoji;
    switch (template.activityType) {
      case 'running':
        emoji = '\u{1F3C3}'; // runner
        break;
      case 'cycling':
        emoji = '\u{1F6B4}'; // cyclist
        break;
      case 'swimming':
        emoji = '\u{1F3CA}'; // swimmer
        break;
      case 'brick':
        // Show multi-sport emojis
        if (template.brickSegmentOrder != null) {
          final segments = template.brickSegmentOrder!;
          final emojis = segments.map((s) {
            switch (s) {
              case 'swimming':
                return '\u{1F3CA}';
              case 'cycling':
                return '\u{1F6B4}';
              case 'running':
                return '\u{1F3C3}';
              default:
                return '\u{1F3C3}';
            }
          }).join();
          emoji = emojis;
        } else {
          emoji = '\u{1F3C3}\u{1F6B4}\u{1F3CA}';
        }
        break;
      default:
        emoji = '\u{1F3C3}';
    }

    return Text(emoji, style: const TextStyle(fontSize: 24));
  }

  Widget _buildSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];

    if (template.activityType != 'brick') {
      parts.add(template.activityTypeDisplay);
    }

    // For brick templates, show segment order
    if (template.activityType == 'brick') {
      final segmentDisplay = template.brickSegmentDisplay;
      if (segmentDisplay != null) {
        parts.add(segmentDisplay);
      }
    }

    // Add saved date
    final savedDate = DateFormat('MMM d').format(template.createdAt);
    parts.add('Saved $savedDate');

    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMacroLine(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];

    if (template.totalCarbsG != null) {
      parts.add('${template.totalCarbsG}g carbs');
    }
    if (template.totalProteinG != null) {
      parts.add('${template.totalProteinG}g protein');
    }
    if (template.totalSodiumMg != null && template.totalSodiumMg! > 0) {
      parts.add('${template.totalSodiumMg}mg sodium');
    }

    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        fontSize: 11,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
