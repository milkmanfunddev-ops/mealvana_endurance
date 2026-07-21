import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

/// Base card for Kyle's design system
/// 15px radius with theme-aware background
class BaseCard extends ConsumerWidget {
  const BaseCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = 0,
    this.border,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final double elevation;
  final Border? border;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = backgroundColor ?? Theme.of(context).colorScheme.surface;
    final cardRadius = borderRadius ?? AppRadius.cardRadius;
    final cardPadding = padding ?? const EdgeInsets.all(AppSpacing.md);

    // Sentry MEALVANA-ENDURANCE-DEV-56: ListTile (and other Material ink
    // descendants such as InkWell) paint their background/splashes on the
    // nearest Material ancestor. Without this, any BaseCard child that
    // nests a ListTile hits Flutter's "ListTile background color or ink
    // splashes may be invisible" assertion because the Container below is a
    // DecoratedBox with a background color and no Material in between.
    // MaterialType.transparency paints nothing itself, so this is purely a
    // Material boundary fix with no visual change.
    Widget card = Material(
      type: MaterialType.transparency,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: cardRadius,
          border: border,
          boxShadow: elevation > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: elevation * 2,
                    offset: Offset(0, elevation),
                  ),
                ]
              : null,
        ),
        child: Padding(padding: cardPadding, child: child),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, borderRadius: cardRadius, child: card),
      );
    }

    return card;
  }
}

/// Card with header and content
class HeaderCard extends ConsumerWidget {
  const HeaderCard({
    super.key,
    required this.header,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.headerPadding,
    this.contentPadding,
    this.headerSpacing = AppSpacing.sm,
  });

  final Widget header;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final EdgeInsets? headerPadding;
  final EdgeInsets? contentPadding;
  final double headerSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseCard(
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: headerPadding ?? EdgeInsets.zero, child: header),
          SizedBox(height: headerSpacing),
          Padding(padding: contentPadding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

/// Card with title and subtitle
class TitledCard extends ConsumerWidget {
  const TitledCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.headerSpacing = AppSpacing.sm,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double headerSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultTitleStyle =
        titleStyle ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        );

    final defaultSubtitleStyle =
        subtitleStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return HeaderCard(
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      headerSpacing: headerSpacing,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: defaultTitleStyle),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: defaultSubtitleStyle),
          ],
        ],
      ),
      child: child,
    );
  }
}

/// Card with action buttons
class ActionCard extends ConsumerWidget {
  const ActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.headerSpacing = AppSpacing.sm,
    this.actionSpacing = AppSpacing.md,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double headerSpacing;
  final double actionSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseCard(
      margin: margin,
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    titleStyle ??
                    Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style:
                      subtitleStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),

          SizedBox(height: headerSpacing),

          // Content
          child,

          // Actions
          if (actions != null && actions!.isNotEmpty) ...[
            SizedBox(height: actionSpacing),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
          ],
        ],
      ),
    );
  }
}
