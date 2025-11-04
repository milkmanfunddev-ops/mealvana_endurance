import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/location.dart' as domain;

/// Location input field widget
/// Allows user to view and edit location for weather forecasts
class LocationInputField extends StatelessWidget {
  final domain.Location? location;
  final VoidCallback onFetchCurrentLocation;
  final VoidCallback onEditLocation;
  final bool isLoadingLocation;

  const LocationInputField({
    super.key,
    required this.location,
    required this.onFetchCurrentLocation,
    required this.onEditLocation,
    this.isLoadingLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Location',
              style: AppTheme.subtitleStyle.copyWith(
                fontSize: 16.sp,
                color: AppTheme.primary900,
              ),
            ),
            if (isLoadingLocation)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary600),
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.primary900, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                size: 20,
                color: location != null ? AppTheme.primary600 : AppTheme.baseGrey,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  location?.displayName ?? 'No location set',
                  style: AppTheme.textStyle.copyWith(
                    fontSize: 14.sp,
                    color: location != null ? AppTheme.primary900 : AppTheme.baseGrey,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: isLoadingLocation ? null : onFetchCurrentLocation,
                icon: Icon(
                  Icons.my_location,
                  size: 20,
                  color: AppTheme.primary600,
                ),
                tooltip: 'Use current location',
              ),
              IconButton(
                onPressed: isLoadingLocation ? null : onEditLocation,
                icon: Icon(
                  Icons.edit_location_alt,
                  size: 20,
                  color: AppTheme.primary600,
                ),
                tooltip: 'Edit location',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
