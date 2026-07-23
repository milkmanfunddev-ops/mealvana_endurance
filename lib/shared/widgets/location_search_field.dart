import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:location_iq/location_iq.dart';
import '../../theme/kyle_design/app_colors.dart';
import '../../theme/kyle_design/app_spacing.dart';
import '../../theme/kyle_design/app_text_styles.dart';
import '../services/location_service.dart';
import '../utils/location_formatter.dart';

/// Self-contained location search field with debounced LocationIQ autocomplete.
///
/// Encapsulates the location search pattern duplicated across 4 event screens.
/// Manages its own focus, debounce timer, and search results dropdown.
class LocationSearchField extends ConsumerStatefulWidget {
  const LocationSearchField({
    super.key,
    required this.controller,
    this.decoration,
    this.onLocationSelected,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.minQueryLength = 3,
    this.maxResults = 5,
  });

  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<LocationIQAutocompleteResult>? onLocationSelected;
  final Duration debounceDuration;
  final int minQueryLength;
  final int maxResults;

  @override
  ConsumerState<LocationSearchField> createState() =>
      _LocationSearchFieldState();
}

class _LocationSearchFieldState extends ConsumerState<LocationSearchField> {
  final _focusNode = FocusNode();
  List<LocationIQAutocompleteResult> _results = [];
  bool _isSearching = false;
  bool _isSelecting = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      _debounceTimer?.cancel();
    }
  }

  void _onTextChanged() {
    if (_isSelecting) return;

    _debounceTimer?.cancel();
    final query = widget.controller.text.trim();

    if (query.isEmpty || query.length < widget.minQueryLength) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(widget.debounceDuration, () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final results = await locationService.searchLocations(
        query,
        limit: widget.maxResults,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectLocation(LocationIQAutocompleteResult location) {
    _isSelecting = true;
    _debounceTimer?.cancel();

    final formatted = LocationFormatter.formatCityState(location);
    setState(() {
      widget.controller.text = formatted;
      _results = [];
      _isSearching = false;
    });

    _focusNode.unfocus();
    widget.onLocationSelected?.call(location);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _isSelecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: _isSearching
              ? widget.decoration?.copyWith(
                  suffixIcon: const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : widget.decoration,
        ),
        if (_results.isNotEmpty)
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.xxs),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: AppRadius.inputRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final location = _results[index];
                  final formatted = LocationFormatter.formatCityState(location);
                  return ListTile(
                    dense: true,
                    leading: FaIcon(
                      FontAwesomeIcons.locationDot,
                      size: AppIconSizes.sm,
                      color: AppColors.electrolyte,
                    ),
                    title: Text(
                      formatted,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectLocation(location),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
