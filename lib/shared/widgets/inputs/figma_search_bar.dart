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
    // Determine what suffix icons to show
    final showBarcode = widget.onBarcodeScan != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.textDark.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextField(
        controller: widget.controller,
        onChanged: _handleTextChanged,
        onSubmitted: widget.onSearchSubmit != null ? (_) => _handleSearchSubmit() : null,
        style: const TextStyle(
          fontFamily: 'Apercu',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textDark,
          letterSpacing: 0.192,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textDark.withValues(alpha: 0.6),
            letterSpacing: 0.192,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.electrolyte,
            size: 24,
          ),
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
