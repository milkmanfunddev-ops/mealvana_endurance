import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../domain/food_item_data.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/utils/food_display_utils.dart' as food_utils;

/// Expandable Food Item Widget with Quantity Controls
/// Displays food item with expandable details and swipe actions
class ExpandableFoodItemWidget extends StatefulWidget {
  const ExpandableFoodItemWidget({
    super.key,
    required this.food,
    required this.getFoodIcon,
    required this.isUserImportedFood,
    required this.getFoodIconColor,
    this.onSwap,
    this.onRemove,
    this.onQuantityChange,
    this.showSwipeHint = false,
    this.useImperial = true,
    this.subtitleOverride,
    this.showQuantity = true,
  });

  final FoodItemData food;
  final IconData Function(String) getFoodIcon;
  final bool Function(FoodItemData) isUserImportedFood;
  final Color Function(FoodItemData) getFoodIconColor;
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final Function(double)? onQuantityChange;
  final bool showSwipeHint;
  final bool useImperial;
  final String? subtitleOverride;

  /// When false, the row title drops the leading quantity (shows the food name
  /// only) and the expanded view hides the +/- quantity stepper. Used by the
  /// personal-formula editor for during formulas, which are intentionally
  /// quantity-less (the solver derives amounts); before/after formulas carry
  /// exact quantities and keep the stepper.
  final bool showQuantity;

  @override
  State<ExpandableFoodItemWidget> createState() =>
      _ExpandableFoodItemWidgetState();
}

class _ExpandableFoodItemWidgetState extends State<ExpandableFoodItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late double _quantity;
  late final AnimationController _swipeHintController;
  late final Animation<double> _swipeHintOffset;
  bool _hasPlayedSwipeHint = false;

  @override
  void initState() {
    super.initState();
    // Extract numeric quantity from the quantity string (e.g., "2 banana" -> 2.0)
    final quantityMatch = RegExp(r'^([\d.]+)').firstMatch(widget.food.quantity);
    _quantity = quantityMatch != null
        ? double.tryParse(quantityMatch.group(1)!) ?? 1.0
        : 1.0;

    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _swipeHintOffset = TweenSequence<double>([
      // Swipe left to show "Delete" button
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -80.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      // Pause on Delete to let user see it
      TweenSequenceItem(tween: ConstantTween(-80.0), weight: 15),
      // Swipe right to show "Swap" button
      TweenSequenceItem(
        tween: Tween(
          begin: -80.0,
          end: 80.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      // Pause on Swap to let user see it
      TweenSequenceItem(tween: ConstantTween(80.0), weight: 15),
      // Return to center
      TweenSequenceItem(
        tween: Tween(
          begin: 80.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_swipeHintController);

    if (widget.showSwipeHint) {
      _playSwipeHint();
    }
  }

  @override
  void didUpdateWidget(covariant ExpandableFoodItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync _quantity when food data changes externally (e.g., summary view update)
    if (widget.food.quantity != oldWidget.food.quantity) {
      final quantityMatch = RegExp(
        r'^([\d.]+)',
      ).firstMatch(widget.food.quantity);
      _quantity = quantityMatch != null
          ? double.tryParse(quantityMatch.group(1)!) ?? 1.0
          : 1.0;
    }
    if (widget.showSwipeHint && !_hasPlayedSwipeHint) {
      _playSwipeHint();
    }
  }

  @override
  void dispose() {
    _swipeHintController.dispose();
    super.dispose();
  }

  void _playSwipeHint() {
    if (_hasPlayedSwipeHint) return;
    _hasPlayedSwipeHint = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _swipeHintController.forward(from: 0);
      }
    });
  }

  /// Convert imperial volume units to metric when user prefers metric.
  /// cups → ml (×237), oz/fl oz → ml (×30).
  /// All other units (packets, bars, servings, tablets, etc.) pass through unchanged.
  String _convertToMetric(String description) {
    // Pattern: number + unit (cups, oz, fl oz)
    final cupsPattern = RegExp(r'(\d+\.?\d*)\s*cups?', caseSensitive: false);
    final ozPattern = RegExp(
      r'(\d+\.?\d*)\s*(fl\s*oz|oz)',
      caseSensitive: false,
    );

    var result = description;

    result = result.replaceAllMapped(cupsPattern, (match) {
      final value = double.tryParse(match.group(1)!) ?? 0;
      final ml = (value * 237).round();
      return '${ml}ml';
    });

    result = result.replaceAllMapped(ozPattern, (match) {
      final value = double.tryParse(match.group(1)!) ?? 0;
      final ml = (value * 30).round();
      return '${ml}ml';
    });

    return result;
  }

  /// Build a human-readable quantity description.
  ///
  /// Always uses [FoodItemData.displayAtQuantity] as the primary display path
  /// to ensure unit prefixes (e.g. "packets Energy Chews") are always shown,
  /// regardless of whether the stored [quantity] field contains a tail.
  String _buildQuantityDescription() {
    final rawQuantity = widget.food.quantity.trim();
    final numericQty = food_utils.parseLeadingQuantity(rawQuantity);
    String description = rawQuantity;

    if (numericQty != null) {
      final roundedQty = _roundFriendlyQuantity(
        numericQty,
        isIndivisible: widget.food.isIndivisible,
      );
      final qtyStr = food_utils.formatQuantity(roundedQty);

      // Use displayAtQuantity as the single source of truth for food display.
      description = widget.food.displayAtQuantity(qtyStr);

      // Preserve any add-on suffix (e.g., "+ 1 Electrolyte Tablet") from
      // the original quantity string.
      final tail = food_utils.parseQuantityTail(rawQuantity);
      final plusMatch = RegExp(r'\+\s*\d').firstMatch(tail);
      if (plusMatch != null) {
        final addOnSuffix = tail.substring(plusMatch.start).trim();
        description = '$description $addOnSuffix';
      }
    } else if (rawQuantity.isEmpty) {
      description = widget.food.displayAtQuantity('1');
    } else {
      description = food_utils.stripParenthetical(rawQuantity);
    }

    // Convert to metric if user prefers metric
    if (!widget.useImperial) {
      description = _convertToMetric(description);
    }

    return description;
  }

  double _roundFriendlyQuantity(double value, {required bool isIndivisible}) {
    if (value <= 0) return isIndivisible ? 1.0 : 0.5;
    if (isIndivisible) return value.round().toDouble();
    return (value * 2).round() / 2; // Snap to nearest 0.5
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.smRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Main row - always visible
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.smRadius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  // Food icon
                  Container(
                    width: AppIconSizes.foodIcon,
                    height: AppIconSizes.foodIcon,
                    decoration: BoxDecoration(
                      color: widget.getFoodIconColor(widget.food),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.getFoodIcon(widget.food.name),
                      size: AppIconSizes.controlIcon,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Quantity-first title and optional explanatory subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.showQuantity
                              ? _buildQuantityDescription()
                              : (widget.food.displayName?.isNotEmpty == true
                                    ? widget.food.displayName!
                                    : widget.food.name),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.subtitleOverride != null &&
                            widget.subtitleOverride!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            widget.subtitleOverride!,
                            style: AppTextStyles.smallLabel.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Chevron icon
                  Icon(
                    _isExpanded
                        ? FontAwesomeIcons.chevronUp.data
                        : FontAwesomeIcons.chevronDown.data,
                    size: AppIconSizes.controlIcon,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity controls (hidden for quantity-less contexts like
                  // the personal-formula editor)
                  if (widget.showQuantity) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quantity',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.orange,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Decrease button
                              IconButton(
                                icon: FaIcon(
                                  FontAwesomeIcons.minus,
                                  size: AppIconSizes.controlIcon,
                                  color: AppColors.orange,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final step = widget.food.isIndivisible
                                        ? 1.0
                                        : 0.5;
                                    if (_quantity > step) {
                                      _quantity -= step;
                                      final updated = widget.food.isIndivisible
                                          ? _quantity.round().toDouble()
                                          : _quantity;
                                      widget.onQuantityChange?.call(updated);
                                    }
                                  });
                                },
                              ),

                              // Quantity display
                              Text(
                                food_utils.formatQuantity(_quantity),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              // Increase button
                              IconButton(
                                icon: FaIcon(
                                  FontAwesomeIcons.plus,
                                  size: AppIconSizes.controlIcon,
                                  color: AppColors.orange,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final step = widget.food.isIndivisible
                                        ? 1.0
                                        : 0.5;
                                    _quantity += step;
                                    final updated = widget.food.isIndivisible
                                        ? _quantity.round().toDouble()
                                        : _quantity;
                                    widget.onQuantityChange?.call(updated);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Nutritional Facts
                  Text(
                    'Nutrition Facts',
                    style: AppTextStyles.smallLabel.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: AppRadius.smRadius,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNutritionItem(
                          context: context,
                          value:
                              '${widget.food.nutritionalInfo?.calories?.toInt() ?? 0}',
                          label: 'CALORIES',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.carbs ?? 0}g',
                          label: 'CARBS',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value:
                              '${widget.food.nutritionalInfo?.protein ?? 0}g',
                          label: 'PROTEIN',
                        ),
                        _buildNutritionItem(
                          context: context,
                          value: '${widget.food.nutritionalInfo?.fat ?? 0}%',
                          label: 'FAT',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Remove food item button
                  if (widget.onRemove != null)
                    InkWell(
                      onTap: widget.onRemove,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.trash,
                            size: AppIconSizes.controlIcon,
                            color: AppColors.dragonfruit,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Remove food item',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.dragonfruit,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!_hasPlayedSwipeHint && !widget.showSwipeHint) {
      return content;
    }

    // Show backgrounds during animation to demonstrate swipe actions
    return AnimatedBuilder(
      animation: _swipeHintOffset,
      builder: (context, child) {
        final offset = _hasPlayedSwipeHint ? _swipeHintOffset.value : 0;

        return ClipRRect(
          borderRadius: AppRadius.smRadius,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Swap background (visible when swiping left - revealed on right side)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: offset < 0
                        ? AppColors.electrolyte
                        : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: offset < 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Swap',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FaIcon(
                              FontAwesomeIcons.arrowRightArrowLeft,
                              color: Colors.white,
                              size: AppIconSizes.md,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Delete background (visible when swiping right - revealed on left side)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: offset > 0
                        ? AppColors.dragonfruit
                        : Colors.transparent,
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: offset > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.trash,
                              color: Colors.white,
                              size: AppIconSizes.md,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Delete',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Animated card on top
              Transform.translate(
                offset: Offset(offset.toDouble(), 0),
                child: child,
              ),
            ],
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildNutritionItem({
    required BuildContext context,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
