import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Unified search bar widget matching Figma onboarding design
///
/// Features:
/// - Simple version: Just search icon (for onboarding)
/// - Advanced version: Barcode scan + debounced OpenFoodFacts search (for other screens)
/// - Purple/cream background matching branded design
/// - Rounded corners (26px radius)
/// - Uses branded AppColors from theme
class FigmaSearchBar extends StatefulWidget {
  const FigmaSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.onBarcodeScan,
    this.onSearchSubmit,
    this.enableAutoSearch = false,
    this.autoSearchDebounceMs = 1000,
    this.useDarkStyle = true,
    this.triggerSearchOnKeyboardSubmit = true,
  });

  /// Text controller for the search field
  final TextEditingController controller;

  /// Called when the search text changes (for local filtering)
  final ValueChanged<String> onChanged;

  /// Hint text to display
  final String hintText;

  /// Optional barcode scan callback (shows barcode icon if provided)
  final VoidCallback? onBarcodeScan;

  /// Optional search submit callback (shows search button if provided, triggers OpenFoodFacts search)
  final ValueChanged<String>? onSearchSubmit;

  /// Enable automatic search after user stops typing
  final bool enableAutoSearch;

  /// Debounce duration in milliseconds for auto-search
  final int autoSearchDebounceMs;

  /// Uses onboarding dark style when true, or theme-aware light style when false.
  final bool useDarkStyle;

  /// Whether keyboard submit (e.g. checkmark/done/search) should trigger
  /// [onSearchSubmit]. Set false to prevent accidental external searches.
  final bool triggerSearchOnKeyboardSubmit;

  @override
  State<FigmaSearchBar> createState() => _FigmaSearchBarState();
}

class _FigmaSearchBarState extends State<FigmaSearchBar> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged(String value) {
    // Always call onChanged for local filtering
    widget.onChanged(value);

    // Handle auto-search if enabled
    if (widget.enableAutoSearch && widget.onSearchSubmit != null) {
      _debounceTimer?.cancel();

      if (value.trim().isNotEmpty) {
        _debounceTimer = Timer(
          Duration(milliseconds: widget.autoSearchDebounceMs),
          () {
            if (mounted) {
              widget.onSearchSubmit!(value.trim());
            }
          },
        );
      }
    }
  }

  void _handleSearchSubmit() {
    _debounceTimer?.cancel();
    final query = widget.controller.text.trim();
    if (query.isNotEmpty && widget.onSearchSubmit != null) {
      widget.onSearchSubmit!(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.useDarkStyle
        ? AppColors.textDark.withValues(alpha: 0.12)
        : theme.colorScheme.surface;
    final borderColor = widget.useDarkStyle
        ? Colors.transparent
        : theme.colorScheme.onSurface.withValues(alpha: 0.14);
    final textColor = widget.useDarkStyle
        ? AppColors.textDark
        : theme.colorScheme.onSurface;
    final hintColor = widget.useDarkStyle
        ? AppColors.textDark.withValues(alpha: 0.6)
        : theme.colorScheme.onSurfaceVariant;
    final prefixIconColor = widget.useDarkStyle
        ? AppColors.electrolyte
        : AppColors.orange;

    // Determine what suffix icons to show
    final showBarcode = widget.onBarcodeScan != null;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: _handleTextChanged,
        onSubmitted: widget.onSearchSubmit == null
            ? null
            : (_) {
                if (widget.triggerSearchOnKeyboardSubmit) {
                  _handleSearchSubmit();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
        style: TextStyle(
          fontFamily: 'Apercu',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
          letterSpacing: 0.192,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: hintColor,
            letterSpacing: 0.192,
          ),
          prefixIcon: Icon(Icons.search, color: prefixIconColor, size: 24),
          suffixIcon: showBarcode
              ? IconButton(
                  icon: const Icon(
                    FontAwesomeIcons.barcode,
                    color: AppColors.orange,
                    size: 20,
                  ),
                  onPressed: widget.onBarcodeScan,
                  tooltip: 'Scan barcode',
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
