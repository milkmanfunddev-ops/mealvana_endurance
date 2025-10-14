// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the device ID for the current user from the user_profiles table.
///
/// This is used throughout the app for user identification since we use
/// device-based identity rather than an authentication system.

@ProviderFor(deviceId)
const deviceIdProvider = DeviceIdProvider._();

/// Provides the device ID for the current user from the user_profiles table.
///
/// This is used throughout the app for user identification since we use
/// device-based identity rather than an authentication system.

final class DeviceIdProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Provides the device ID for the current user from the user_profiles table.
  ///
  /// This is used throughout the app for user identification since we use
  /// device-based identity rather than an authentication system.
  const DeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceIdHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return deviceId(ref);
  }
}

String _$deviceIdHash() => r'fb461357ee513a94592c7c3e5756eaf3d38ce1f8';
