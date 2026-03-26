import 'package:flutter/material.dart';

/// Branded app bar back button used across the app.
///
/// Uses a circular translucent background to match the current Kyle UI,
/// with tap debouncing to prevent double-pop crashes.
class CustomAppBarBackButton extends StatefulWidget {
  const CustomAppBarBackButton({
    super.key,
    this.onPressed,
    this.margin = const EdgeInsets.only(left: 12, top: 8, bottom: 8),
    this.iconColor,
    this.backgroundColor,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final EdgeInsetsGeometry margin;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool enabled;

  @override
  State<CustomAppBarBackButton> createState() => _CustomAppBarBackButtonState();
}

class _CustomAppBarBackButtonState extends State<CustomAppBarBackButton> {
  bool _isProcessing = false;

  void _handleTap() async {
    if (!widget.enabled) return;

    // Prevent double-tap by checking if already processing
    if (_isProcessing) return;

    _isProcessing = true;

    // Execute the callback
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    // Reset _isProcessing after a short delay to allow for state updates
    // without permanently locking the button if the widget isn't disposed.
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconColor = widget.iconColor ?? onSurface;
    final backgroundColor =
        widget.backgroundColor ?? onSurface.withValues(alpha: 0.1);

    return Container(
      margin: widget.margin,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.enabled ? _handleTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: _BackIcon(iconColor: iconColor),
          ),
        ),
      ),
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({required this.iconColor});

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(Icons.arrow_back, color: iconColor, size: 20),
      ),
    );
  }
}
