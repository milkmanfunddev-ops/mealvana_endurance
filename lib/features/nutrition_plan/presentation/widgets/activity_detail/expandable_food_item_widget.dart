import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../domain/food_item_data.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

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

  /// Build a human-readable quantity description
  /// Uses quantity-first phrasing with simplified food names.
  String _buildQuantityDescription() {
    final rawQuantity = widget.food.quantity.trim();
    final numericQty = _parseLeadingQuantity(rawQuantity);
    String description = rawQuantity;

    if (numericQty != null) {
      final roundedQty = _roundFriendlyQuantity(
        numericQty,
        isIndivisible: widget.food.isIndivisible,
      );
      final qtyStr = _formatQuantityNumber(roundedQty);
      final tail = _parseQuantityTail(rawQuantity);

      // Separate any add-on suffix (e.g., "+ 1 Electrolyte Tablet") from
      // the main quantity tail so the food name is still resolved correctly.
      String addOnSuffix = '';
      String mainTail = tail;
      final plusMatch = RegExp(r'\+\s*\d').firstMatch(tail);
      if (plusMatch != null) {
        addOnSuffix = ' ${tail.substring(plusMatch.start).trim()}';
        mainTail = tail.substring(0, plusMatch.start).trim();
      }

      final hasUsefulTail =
          mainTail.isNotEmpty && !mainTail.toLowerCase().startsWith('x ');

      if (hasUsefulTail) {
        description = '$qtyStr ${_simplifyName(mainTail)}$addOnSuffix';
      } else {
        description = '$qtyStr ${_resolveSimpleFoodName(roundedQty)}$addOnSuffix';
      }
    } else if (rawQuantity.isEmpty) {
      description = _resolveSimpleFoodName(1.0);
    } else {
      description = _simplifyName(rawQuantity);
    }

    // Convert to metric if user prefers metric
    if (!widget.useImperial) {
      description = _convertToMetric(description);
    }

    return description;
  }

  double? _parseLeadingQuantity(String raw) {
    final match = RegExp(r'^([\d.]+)').firstMatch(raw);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  String _parseQuantityTail(String raw) {
    final match = RegExp(r'^[\d.]+\s*(.*)$').firstMatch(raw);
    return (match?.group(1) ?? '').trim();
  }

  String _resolveSimpleFoodName(double quantity) {
    final singularRaw = widget.food.displayName?.isNotEmpty == true
        ? widget.food.displayName!
        : widget.food.name;

    // If we have servingSize with a unit (e.g. "1 cup cooked"), use unit + food name
    // instead of naively pluralizing (avoids "Oatmeals", "Honeys", "Milks").
    if (quantity != 1) {
      final unitLabel = _extractUnitFromServingSize();
      if (unitLabel != null) {
        return '$unitLabel ${_simplifyName(singularRaw)}';
      }
    }

    final pluralRaw = widget.food.displayNamePlural?.isNotEmpty == true
        ? widget.food.displayNamePlural!
        : _pluralize(singularRaw);
    return _simplifyName(quantity == 1 ? singularRaw : pluralRaw);
  }

  /// Extract the measurement unit from servingSize (e.g. "1 cup cooked" → "cups").
  /// Returns the pluralized unit if recognized, null otherwise.
  String? _extractUnitFromServingSize() {
    final servingSize = widget.food.servingSize;
    if (servingSize == null || servingSize.isEmpty) return null;

    // Match leading number (digits, fractions like 1/2, or Unicode fractions
    // like ½, ¼, ¾, or mixed like "1½") followed by the unit word
    final match = RegExp(
      r'^[\d./½¼¾⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞]+\s+(\S+)',
    ).firstMatch(servingSize.trim());
    final unit = match?.group(1)?.trim();
    if (unit == null) return null;

    // Only return recognized measurement units
    const knownUnits = {
      'cup', 'cups', 'tbsp', 'tsp', 'oz', 'ml', 'g', 'mg', 'kg', 'l',
      'slice', 'slices', 'piece', 'pieces', 'scoop', 'scoops',
      'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
      'packet', 'packets', 'serving', 'servings',
      'pouch', 'pouches', 'bottle', 'bottles', 'shot', 'shots',
      'bar', 'bars', 'waffle', 'waffles', 'sheet', 'sheets',
    };
    if (!knownUnits.contains(unit.toLowerCase())) return null;
    return _pluralizeUnit(unit);
  }

  static String _pluralizeUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    if (const {'tbsp', 'tsp', 'oz', 'ml', 'g', 'mg', 'kg', 'l', 'fl oz'}
        .contains(lower)) {
      return unit;
    }
    if (lower.endsWith('s')) return unit;
    if (lower.endsWith('ch') || lower.endsWith('sh') || lower.endsWith('x')) {
      return '${unit}es';
    }
    return '${unit}s';
  }

  String _pluralize(String value) {
    // Strip parenthetical content first to avoid bugs like
    // "Dates (Medjool)" → "Dates (Medjool)s" → "Datess"
    final simplified = value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (simplified.toLowerCase().endsWith('s')) return simplified;
    return '${simplified}s';
  }

  String _simplifyName(String value) {
    final noParen = value.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    return noParen.trim();
  }

  double _roundFriendlyQuantity(double value, {required bool isIndivisible}) {
    if (value <= 0) return isIndivisible ? 1.0 : 0.5;
    if (isIndivisible) return value.round().toDouble();
    return (value * 2).round() / 2; // Snap to nearest 0.5
  }

  String _formatQuantityNumber(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    if ((value * 10 - (value * 10).round()).abs() < 0.01) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
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
                          _buildQuantityDescription(),
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
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
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
                  // Quantity controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.orange, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Decrease button
                            IconButton(
                              icon: Icon(
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
                              _formatQuantityNumber(_quantity),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // Increase button
                            IconButton(
                              icon: Icon(
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
                          Icon(
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
                            Icon(
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
                            Icon(
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
