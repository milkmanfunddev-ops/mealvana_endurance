// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userBoxHash() => r'a70bcea70ee0c32281f6eaaced6aef053b6e3457';

/// User box provider
///
/// Copied from [userBox].
@ProviderFor(userBox)
final userBoxProvider = FutureProvider<Box<UserProfile>>.internal(
  userBox,
  name: r'userBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$userBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserBoxRef = FutureProviderRef<Box<UserProfile>>;
String _$preferencesBoxHash() => r'cbce747fb0d46d3807c130cf612397385accad92';

/// Preferences box provider
///
/// Copied from [preferencesBox].
@ProviderFor(preferencesBox)
final preferencesBoxProvider = FutureProvider<Box<FoodPreferences>>.internal(
  preferencesBox,
  name: r'preferencesBoxProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$preferencesBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PreferencesBoxRef = FutureProviderRef<Box<FoodPreferences>>;
String _$userRepositoryHash() => r'1c362cf15e5d71346ecef18c1baaf2504be2405a';

/// Repository provider following Andrea's pattern
///
/// Copied from [userRepository].
@ProviderFor(userRepository)
final userRepositoryProvider = AutoDisposeProvider<UserRepository>.internal(
  userRepository,
  name: r'userRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserRepositoryRef = AutoDisposeProviderRef<UserRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
