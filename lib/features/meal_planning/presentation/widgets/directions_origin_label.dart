import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/directions_origin.dart';
import '../../domain/meal_detail.dart';

/// Where a recipe's steps came from (mp-146), one label per origin:
///
/// - `source` — "As published by X · host", tap opens the original;
/// - `alt_source` — "Steps from X", linked when the source has a url;
/// - `assembly_simple` — "A simple assembly, no recipe needed";
/// - `ai_generated` — the sparkle badge with the AI disclaimer tooltip.
///
/// No recorded origin renders nothing. Links go through [onOpen] so the
/// screen keeps the app's url launcher and a test can record the tap.
class DirectionsOriginLabel extends ConsumerWidget {
  const DirectionsOriginLabel({
    super.key,
    required this.directions,
    required this.onOpen,
  });

  final MealDirections directions;

  /// Opens the original, `launchUrl`-shaped.
  final Future<bool> Function(Uri uri) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final uri = switch (directions.sourceUrl) {
      final url? when url.isNotEmpty => Uri.tryParse(url),
      _ => null,
    };
    final host = uri?.host.replaceFirst('www.', '');

    switch (directions.origin) {
      case null:
        return const SizedBox.shrink();
      case DirectionsOrigin.aiGenerated:
        return _AiBadge(
          label: content.getValue(ContentKeys.mpBadgeAiGenerated),
          tooltip: content.getValue(ContentKeys.mpCookAiDisclaimer),
        );
      case DirectionsOrigin.assemblySimple:
        return _OriginText(
          text: content.getValue(ContentKeys.mpOriginAssembly),
        );
      case DirectionsOrigin.source:
      case DirectionsOrigin.altSource:
        final name = switch (directions.sourceName) {
          final n? when n.isNotEmpty => n,
          _ => host,
        };
        if (name == null || name.isEmpty) return const SizedBox.shrink();
        final key = directions.origin == DirectionsOrigin.source
            ? ContentKeys.mpOriginVerbatim
            : ContentKeys.mpOriginAltSource;
        final text = ContentKeys.format(content.getValue(key), {'name': name});
        if (uri == null) return _OriginText(text: text);
        return _OriginLink(
          text: text,
          host: host ?? '',
          onTap: () => onOpen(uri),
        );
    }
  }
}

/// Plain provenance line (alternate source without a url, simple assembly).
class _OriginText extends StatelessWidget {
  const _OriginText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.6);
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(color: secondary, fontSize: 13),
    );
  }
}

/// "↗ As published by X · host" — the whole row opens the original.
class _OriginLink extends StatelessWidget {
  const _OriginLink({
    required this.text,
    required this.host,
    required this.onTap,
  });

  final String text;
  final String host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.6);

    return GestureDetector(
      key: const ValueKey('meal_planning.detail_origin_link'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.arrowUpRightFromSquare,
            size: 12,
            color: accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (host.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "✦ AI-written steps" with the disclaimer tooltip — unchanged from the
/// badge the minimal layout already carried.
class _AiBadge extends StatelessWidget {
  const _AiBadge({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.orange.withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.wandMagicSparkles,
              size: 11,
              color: AppColors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
