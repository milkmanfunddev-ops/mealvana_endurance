import 'package:flutter/material.dart';

import '../../../../../theme/kyle_design/app_colors.dart';

/// Reusable accordion widget for the transparency sections (Video, Full Story).
class TransparencyAccordion extends StatefulWidget {
  const TransparencyAccordion({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.onExpanded,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  /// Called when the user expands the accordion (not on collapse, and not on
  /// the initial build). Optional because this widget also wraps the
  /// calculation and video sections, which don't track expansion.
  final VoidCallback? onExpanded;

  @override
  State<TransparencyAccordion> createState() => _TransparencyAccordionState();
}

class _TransparencyAccordionState extends State<TransparencyAccordion>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _isExpanded ? 1.0 : 0.0,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    _iconTurns = _controller.drive(
      Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    if (_isExpanded) {
      widget.onExpanded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    final expandedLabelColor =
        isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: borderColor),
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isExpanded ? expandedLabelColor : labelColor,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: _iconTurns,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isExpanded ? AppColors.electrolyte : labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                heightFactor: _heightFactor.value,
                child: Opacity(
                  opacity: _controller.value,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
