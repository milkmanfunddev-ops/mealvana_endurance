import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../theme/app_theme.dart';

/// Unified search bar for food selection across different screens
/// Configurable to show/hide filter button based on context
class FoodSearchBar extends StatelessWidget {
  const FoodSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onBarcodeScan,
    this.onChanged,
    this.showFilters = false,
    this.onFilterToggle,
    this.filtersEnabled = false,
    this.hintText = 'Search foods...',
    this.showClearButton = false,
    this.onClear,
  });

  final TextEditingController controller;
  final Function(String) onSearch;
  final Function(String)? onChanged;
  final VoidCallback onBarcodeScan;
  final bool showFilters;
  final VoidCallback? onFilterToggle;
  final bool filtersEnabled;
  final String hintText;
  final bool showClearButton;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      color: AppTheme.baseCream,
      child: Column(
        children: [
          Row(
            children: [
              // Search input field
              Expanded(
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppTheme.baseWhite,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: AppTheme.primary100),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            filled: false,
                            hintText: hintText,
                            contentPadding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
                          ),
                          onSubmitted: (_) => onSearch(controller.text),
                          onChanged: (value) {
                            // For real-time search filtering (not API search)
                            if (onChanged != null) {
                              onChanged!(value);
                            } else {
                              // Fallback: clear search when empty
                              if (value.isEmpty) {
                                onSearch('');
                              }
                            }
                          },
                        ),
                      ),

                      // Barcode button
                      GestureDetector(
                        onTap: onBarcodeScan,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(6.w, 12.h, 0.w, 12.h),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: AppTheme.primary600,
                            size: 20.sp,
                          ),
                        ),
                      ),

                      // Filter button (only show for preferences screen)
                      if (showFilters) ...[
                        GestureDetector(
                          onTap: onFilterToggle,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(6.w, 12.h, 8.w, 12.h),
                            child: Icon(
                              Icons.filter_list,
                              color: filtersEnabled ? AppTheme.primary600 : AppTheme.primary100,
                              size: 20.sp,
                            ),
                          ),
                        ),
                      ] else ...[
                        // Add padding to match when no filter button
                        SizedBox(width: 8.w),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(width: 8.w),

              // Search button
              GestureDetector(
                onTap: () => onSearch(controller.text),
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary600,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Center(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        color: AppTheme.baseWhite,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Clear search button (when showing results)
          if (showClearButton) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary100,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear, size: 16.sp, color: AppTheme.primary600),
                    SizedBox(width: 4.w),
                    Text(
                      'Clear Search',
                      style: TextStyle(
                        color: AppTheme.primary600,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}