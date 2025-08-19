// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contentBoxHash() => r'98f56dc0b685ac18540072c3f0d1d568bfe5f53e';

/// Content box provider
///
/// Copied from [contentBox].
@ProviderFor(contentBox)
final contentBoxProvider = FutureProvider<Box<AppContent>>.internal(
  contentBox,
  name: r'contentBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$contentBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContentBoxRef = FutureProviderRef<Box<AppContent>>;
String _$contentRepositoryHash() => r'af8289c1c28a5329a058499f13e736b1bde5e26e';

/// Repository provider following Andrea's pattern
///
/// Copied from [contentRepository].
@ProviderFor(contentRepository)
final contentRepositoryProvider =
    AutoDisposeProvider<ContentRepository>.internal(
  contentRepository,
  name: r'contentRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$contentRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContentRepositoryRef = AutoDisposeProviderRef<ContentRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
