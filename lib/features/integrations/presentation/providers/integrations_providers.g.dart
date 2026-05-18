// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integrations_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for app package info (version, build number, etc.)

@ProviderFor(packageInfo)
const packageInfoProvider = PackageInfoProvider._();

/// Provider for app package info (version, build number, etc.)

final class PackageInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<PackageInfo>,
          PackageInfo,
          FutureOr<PackageInfo>
        >
    with $FutureModifier<PackageInfo>, $FutureProvider<PackageInfo> {
  /// Provider for app package info (version, build number, etc.)
  const PackageInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packageInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packageInfoHash();

  @$internal
  @override
  $FutureProviderElement<PackageInfo> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PackageInfo> create(Ref ref) {
    return packageInfo(ref);
  }
}

String _$packageInfoHash() => r'41f10b7668cfc9d09df704d18b851ed9440397d6';

/// Provider for Final Surge API client

@ProviderFor(finalSurgeApiClient)
const finalSurgeApiClientProvider = FinalSurgeApiClientProvider._();

/// Provider for Final Surge API client

final class FinalSurgeApiClientProvider
    extends
        $FunctionalProvider<
          FinalSurgeApiClient,
          FinalSurgeApiClient,
          FinalSurgeApiClient
        >
    with $Provider<FinalSurgeApiClient> {
  /// Provider for Final Surge API client
  const FinalSurgeApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finalSurgeApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finalSurgeApiClientHash();

  @$internal
  @override
  $ProviderElement<FinalSurgeApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinalSurgeApiClient create(Ref ref) {
    return finalSurgeApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinalSurgeApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinalSurgeApiClient>(value),
    );
  }
}

String _$finalSurgeApiClientHash() =>
    r'8163e1ff1d52142bb21af1b1cf69e319c52de5a6';

/// Provider for integrations repository

@ProviderFor(integrationsRepository)
const integrationsRepositoryProvider = IntegrationsRepositoryProvider._();

/// Provider for integrations repository

final class IntegrationsRepositoryProvider
    extends
        $FunctionalProvider<
          IntegrationsRepository,
          IntegrationsRepository,
          IntegrationsRepository
        >
    with $Provider<IntegrationsRepository> {
  /// Provider for integrations repository
  const IntegrationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'integrationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$integrationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<IntegrationsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IntegrationsRepository create(Ref ref) {
    return integrationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IntegrationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IntegrationsRepository>(value),
    );
  }
}

String _$integrationsRepositoryHash() =>
    r'9216aa72e31fcc8c9aeb6bfaac9f977ac5da799b';

/// Provider for Final Surge OAuth service

@ProviderFor(finalSurgeOAuthService)
const finalSurgeOAuthServiceProvider = FinalSurgeOAuthServiceProvider._();

/// Provider for Final Surge OAuth service

final class FinalSurgeOAuthServiceProvider
    extends
        $FunctionalProvider<
          FinalSurgeOAuthService,
          FinalSurgeOAuthService,
          FinalSurgeOAuthService
        >
    with $Provider<FinalSurgeOAuthService> {
  /// Provider for Final Surge OAuth service
  const FinalSurgeOAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finalSurgeOAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finalSurgeOAuthServiceHash();

  @$internal
  @override
  $ProviderElement<FinalSurgeOAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinalSurgeOAuthService create(Ref ref) {
    return finalSurgeOAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinalSurgeOAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinalSurgeOAuthService>(value),
    );
  }
}

String _$finalSurgeOAuthServiceHash() =>
    r'04a3926f98bdf129209c8d842114984e9f635a39';

/// Provider for Final Surge transformer

@ProviderFor(finalSurgeTransformer)
const finalSurgeTransformerProvider = FinalSurgeTransformerProvider._();

/// Provider for Final Surge transformer

final class FinalSurgeTransformerProvider
    extends
        $FunctionalProvider<
          FinalSurgeTransformer,
          FinalSurgeTransformer,
          FinalSurgeTransformer
        >
    with $Provider<FinalSurgeTransformer> {
  /// Provider for Final Surge transformer
  const FinalSurgeTransformerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finalSurgeTransformerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finalSurgeTransformerHash();

  @$internal
  @override
  $ProviderElement<FinalSurgeTransformer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinalSurgeTransformer create(Ref ref) {
    return finalSurgeTransformer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinalSurgeTransformer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinalSurgeTransformer>(value),
    );
  }
}

String _$finalSurgeTransformerHash() =>
    r'a4b7b7b85ef111098bae59045c76fc70a96a57da';

/// Provider for Final Surge sync service

@ProviderFor(finalSurgeSyncService)
const finalSurgeSyncServiceProvider = FinalSurgeSyncServiceProvider._();

/// Provider for Final Surge sync service

final class FinalSurgeSyncServiceProvider
    extends
        $FunctionalProvider<
          FinalSurgeSyncService,
          FinalSurgeSyncService,
          FinalSurgeSyncService
        >
    with $Provider<FinalSurgeSyncService> {
  /// Provider for Final Surge sync service
  const FinalSurgeSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'finalSurgeSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$finalSurgeSyncServiceHash();

  @$internal
  @override
  $ProviderElement<FinalSurgeSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FinalSurgeSyncService create(Ref ref) {
    return finalSurgeSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FinalSurgeSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FinalSurgeSyncService>(value),
    );
  }
}

String _$finalSurgeSyncServiceHash() =>
    r'f49896992377053541a17a5dc89cdecd7594288f';

/// Provider to get Final Surge integration for a user

@ProviderFor(finalSurgeIntegration)
const finalSurgeIntegrationProvider = FinalSurgeIntegrationFamily._();

/// Provider to get Final Surge integration for a user

final class FinalSurgeIntegrationProvider
    extends
        $FunctionalProvider<
          AsyncValue<IntegrationModel?>,
          IntegrationModel?,
          FutureOr<IntegrationModel?>
        >
    with
        $FutureModifier<IntegrationModel?>,
        $FutureProvider<IntegrationModel?> {
  /// Provider to get Final Surge integration for a user
  const FinalSurgeIntegrationProvider._({
    required FinalSurgeIntegrationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'finalSurgeIntegrationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$finalSurgeIntegrationHash();

  @override
  String toString() {
    return r'finalSurgeIntegrationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<IntegrationModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<IntegrationModel?> create(Ref ref) {
    final argument = this.argument as String;
    return finalSurgeIntegration(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FinalSurgeIntegrationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$finalSurgeIntegrationHash() =>
    r'1850d1d44d08a9303e56e8fe8c6fd09fe79b85f5';

/// Provider to get Final Surge integration for a user

final class FinalSurgeIntegrationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<IntegrationModel?>, String> {
  const FinalSurgeIntegrationFamily._()
    : super(
        retry: null,
        name: r'finalSurgeIntegrationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get Final Surge integration for a user

  FinalSurgeIntegrationProvider call(String userId) =>
      FinalSurgeIntegrationProvider._(argument: userId, from: this);

  @override
  String toString() => r'finalSurgeIntegrationProvider';
}

/// Provider to check if Final Surge is connected

@ProviderFor(isFinalSurgeConnected)
const isFinalSurgeConnectedProvider = IsFinalSurgeConnectedFamily._();

/// Provider to check if Final Surge is connected

final class IsFinalSurgeConnectedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if Final Surge is connected
  const IsFinalSurgeConnectedProvider._({
    required IsFinalSurgeConnectedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isFinalSurgeConnectedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isFinalSurgeConnectedHash();

  @override
  String toString() {
    return r'isFinalSurgeConnectedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isFinalSurgeConnected(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsFinalSurgeConnectedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isFinalSurgeConnectedHash() =>
    r'58b0d3a3beb37181087109e12ae03eece8614bf8';

/// Provider to check if Final Surge is connected

final class IsFinalSurgeConnectedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const IsFinalSurgeConnectedFamily._()
    : super(
        retry: null,
        name: r'isFinalSurgeConnectedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to check if Final Surge is connected

  IsFinalSurgeConnectedProvider call(String userId) =>
      IsFinalSurgeConnectedProvider._(argument: userId, from: this);

  @override
  String toString() => r'isFinalSurgeConnectedProvider';
}

/// Provider for all user integrations

@ProviderFor(userIntegrations)
const userIntegrationsProvider = UserIntegrationsFamily._();

/// Provider for all user integrations

final class UserIntegrationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<IntegrationModel>>,
          List<IntegrationModel>,
          FutureOr<List<IntegrationModel>>
        >
    with
        $FutureModifier<List<IntegrationModel>>,
        $FutureProvider<List<IntegrationModel>> {
  /// Provider for all user integrations
  const UserIntegrationsProvider._({
    required UserIntegrationsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userIntegrationsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userIntegrationsHash();

  @override
  String toString() {
    return r'userIntegrationsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<IntegrationModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<IntegrationModel>> create(Ref ref) {
    final argument = this.argument as String;
    return userIntegrations(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserIntegrationsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userIntegrationsHash() => r'ee469f9afef7692310e1aafee2cc50d7f9f49959';

/// Provider for all user integrations

final class UserIntegrationsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<IntegrationModel>>, String> {
  const UserIntegrationsFamily._()
    : super(
        retry: null,
        name: r'userIntegrationsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider for all user integrations

  UserIntegrationsProvider call(String userId) =>
      UserIntegrationsProvider._(argument: userId, from: this);

  @override
  String toString() => r'userIntegrationsProvider';
}

/// Provider for TrainingPeaks API client

@ProviderFor(trainingPeaksApiClient)
const trainingPeaksApiClientProvider = TrainingPeaksApiClientProvider._();

/// Provider for TrainingPeaks API client

final class TrainingPeaksApiClientProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPeaksApiClient>,
          TrainingPeaksApiClient,
          FutureOr<TrainingPeaksApiClient>
        >
    with
        $FutureModifier<TrainingPeaksApiClient>,
        $FutureProvider<TrainingPeaksApiClient> {
  /// Provider for TrainingPeaks API client
  const TrainingPeaksApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPeaksApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPeaksApiClientHash();

  @$internal
  @override
  $FutureProviderElement<TrainingPeaksApiClient> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrainingPeaksApiClient> create(Ref ref) {
    return trainingPeaksApiClient(ref);
  }
}

String _$trainingPeaksApiClientHash() =>
    r'29d96aa2470b4626fa0bae693c6b4c474a418460';

/// Provider for TrainingPeaks transformer

@ProviderFor(trainingPeaksTransformer)
const trainingPeaksTransformerProvider = TrainingPeaksTransformerProvider._();

/// Provider for TrainingPeaks transformer

final class TrainingPeaksTransformerProvider
    extends
        $FunctionalProvider<
          TrainingPeaksTransformer,
          TrainingPeaksTransformer,
          TrainingPeaksTransformer
        >
    with $Provider<TrainingPeaksTransformer> {
  /// Provider for TrainingPeaks transformer
  const TrainingPeaksTransformerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPeaksTransformerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPeaksTransformerHash();

  @$internal
  @override
  $ProviderElement<TrainingPeaksTransformer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrainingPeaksTransformer create(Ref ref) {
    return trainingPeaksTransformer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainingPeaksTransformer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainingPeaksTransformer>(value),
    );
  }
}

String _$trainingPeaksTransformerHash() =>
    r'46b78b1659a485391a10d36ae825bab76f78abb5';

/// Provider for TrainingPeaks OAuth service

@ProviderFor(trainingPeaksOAuthService)
const trainingPeaksOAuthServiceProvider = TrainingPeaksOAuthServiceProvider._();

/// Provider for TrainingPeaks OAuth service

final class TrainingPeaksOAuthServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPeaksOAuthService>,
          TrainingPeaksOAuthService,
          FutureOr<TrainingPeaksOAuthService>
        >
    with
        $FutureModifier<TrainingPeaksOAuthService>,
        $FutureProvider<TrainingPeaksOAuthService> {
  /// Provider for TrainingPeaks OAuth service
  const TrainingPeaksOAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPeaksOAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPeaksOAuthServiceHash();

  @$internal
  @override
  $FutureProviderElement<TrainingPeaksOAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrainingPeaksOAuthService> create(Ref ref) {
    return trainingPeaksOAuthService(ref);
  }
}

String _$trainingPeaksOAuthServiceHash() =>
    r'7d5954d73d8a358583e1a7a3bda1067dab579b72';

/// Provider for TrainingPeaks sync service

@ProviderFor(trainingPeaksSyncService)
const trainingPeaksSyncServiceProvider = TrainingPeaksSyncServiceProvider._();

/// Provider for TrainingPeaks sync service

final class TrainingPeaksSyncServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrainingPeaksSyncService>,
          TrainingPeaksSyncService,
          FutureOr<TrainingPeaksSyncService>
        >
    with
        $FutureModifier<TrainingPeaksSyncService>,
        $FutureProvider<TrainingPeaksSyncService> {
  /// Provider for TrainingPeaks sync service
  const TrainingPeaksSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainingPeaksSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainingPeaksSyncServiceHash();

  @$internal
  @override
  $FutureProviderElement<TrainingPeaksSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrainingPeaksSyncService> create(Ref ref) {
    return trainingPeaksSyncService(ref);
  }
}

String _$trainingPeaksSyncServiceHash() =>
    r'b52b93f4c6b35c7a3d5c879adfec78add94d6d44';

/// Provider to get TrainingPeaks integration for a user

@ProviderFor(trainingPeaksIntegration)
const trainingPeaksIntegrationProvider = TrainingPeaksIntegrationFamily._();

/// Provider to get TrainingPeaks integration for a user

final class TrainingPeaksIntegrationProvider
    extends
        $FunctionalProvider<
          AsyncValue<IntegrationModel?>,
          IntegrationModel?,
          FutureOr<IntegrationModel?>
        >
    with
        $FutureModifier<IntegrationModel?>,
        $FutureProvider<IntegrationModel?> {
  /// Provider to get TrainingPeaks integration for a user
  const TrainingPeaksIntegrationProvider._({
    required TrainingPeaksIntegrationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'trainingPeaksIntegrationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$trainingPeaksIntegrationHash();

  @override
  String toString() {
    return r'trainingPeaksIntegrationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<IntegrationModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<IntegrationModel?> create(Ref ref) {
    final argument = this.argument as String;
    return trainingPeaksIntegration(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TrainingPeaksIntegrationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$trainingPeaksIntegrationHash() =>
    r'2ca305fabdc4fab8e4d733ce536cafa2e985f54c';

/// Provider to get TrainingPeaks integration for a user

final class TrainingPeaksIntegrationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<IntegrationModel?>, String> {
  const TrainingPeaksIntegrationFamily._()
    : super(
        retry: null,
        name: r'trainingPeaksIntegrationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get TrainingPeaks integration for a user

  TrainingPeaksIntegrationProvider call(String userId) =>
      TrainingPeaksIntegrationProvider._(argument: userId, from: this);

  @override
  String toString() => r'trainingPeaksIntegrationProvider';
}

/// Provider to check if TrainingPeaks is connected

@ProviderFor(isTrainingPeaksConnected)
const isTrainingPeaksConnectedProvider = IsTrainingPeaksConnectedFamily._();

/// Provider to check if TrainingPeaks is connected

final class IsTrainingPeaksConnectedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if TrainingPeaks is connected
  const IsTrainingPeaksConnectedProvider._({
    required IsTrainingPeaksConnectedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isTrainingPeaksConnectedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isTrainingPeaksConnectedHash();

  @override
  String toString() {
    return r'isTrainingPeaksConnectedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isTrainingPeaksConnected(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsTrainingPeaksConnectedProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isTrainingPeaksConnectedHash() =>
    r'02f8246840744ccd8238b65561c6de1c4ccc6da4';

/// Provider to check if TrainingPeaks is connected

final class IsTrainingPeaksConnectedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const IsTrainingPeaksConnectedFamily._()
    : super(
        retry: null,
        name: r'isTrainingPeaksConnectedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to check if TrainingPeaks is connected

  IsTrainingPeaksConnectedProvider call(String userId) =>
      IsTrainingPeaksConnectedProvider._(argument: userId, from: this);

  @override
  String toString() => r'isTrainingPeaksConnectedProvider';
}

/// Provider for Garmin Connect OAuth service
///
/// Garmin is push-only — no sync service or API client needed.
/// Activities arrive automatically via server-side push.

@ProviderFor(garminOAuthService)
const garminOAuthServiceProvider = GarminOAuthServiceProvider._();

/// Provider for Garmin Connect OAuth service
///
/// Garmin is push-only — no sync service or API client needed.
/// Activities arrive automatically via server-side push.

final class GarminOAuthServiceProvider
    extends
        $FunctionalProvider<
          GarminOAuthService,
          GarminOAuthService,
          GarminOAuthService
        >
    with $Provider<GarminOAuthService> {
  /// Provider for Garmin Connect OAuth service
  ///
  /// Garmin is push-only — no sync service or API client needed.
  /// Activities arrive automatically via server-side push.
  const GarminOAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'garminOAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$garminOAuthServiceHash();

  @$internal
  @override
  $ProviderElement<GarminOAuthService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GarminOAuthService create(Ref ref) {
    return garminOAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GarminOAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GarminOAuthService>(value),
    );
  }
}

String _$garminOAuthServiceHash() =>
    r'13a899004fc28cb477a0c64c5ad81ae033f42cca';

/// Provider to get Garmin Connect integration for a user

@ProviderFor(garminIntegration)
const garminIntegrationProvider = GarminIntegrationFamily._();

/// Provider to get Garmin Connect integration for a user

final class GarminIntegrationProvider
    extends
        $FunctionalProvider<
          AsyncValue<IntegrationModel?>,
          IntegrationModel?,
          FutureOr<IntegrationModel?>
        >
    with
        $FutureModifier<IntegrationModel?>,
        $FutureProvider<IntegrationModel?> {
  /// Provider to get Garmin Connect integration for a user
  const GarminIntegrationProvider._({
    required GarminIntegrationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'garminIntegrationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$garminIntegrationHash();

  @override
  String toString() {
    return r'garminIntegrationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<IntegrationModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<IntegrationModel?> create(Ref ref) {
    final argument = this.argument as String;
    return garminIntegration(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GarminIntegrationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$garminIntegrationHash() => r'25d48d7f5ce70b70531e14813d0017575abd05a9';

/// Provider to get Garmin Connect integration for a user

final class GarminIntegrationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<IntegrationModel?>, String> {
  const GarminIntegrationFamily._()
    : super(
        retry: null,
        name: r'garminIntegrationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get Garmin Connect integration for a user

  GarminIntegrationProvider call(String userId) =>
      GarminIntegrationProvider._(argument: userId, from: this);

  @override
  String toString() => r'garminIntegrationProvider';
}

/// Provider to check if Garmin Connect is connected

@ProviderFor(isGarminConnected)
const isGarminConnectedProvider = IsGarminConnectedFamily._();

/// Provider to check if Garmin Connect is connected

final class IsGarminConnectedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check if Garmin Connect is connected
  const IsGarminConnectedProvider._({
    required IsGarminConnectedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isGarminConnectedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isGarminConnectedHash();

  @override
  String toString() {
    return r'isGarminConnectedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isGarminConnected(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsGarminConnectedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isGarminConnectedHash() => r'3de352bda711ec27cf893833d1f5831f09612c3b';

/// Provider to check if Garmin Connect is connected

final class IsGarminConnectedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const IsGarminConnectedFamily._()
    : super(
        retry: null,
        name: r'isGarminConnectedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to check if Garmin Connect is connected

  IsGarminConnectedProvider call(String userId) =>
      IsGarminConnectedProvider._(argument: userId, from: this);

  @override
  String toString() => r'isGarminConnectedProvider';
}

/// Fetches the latest body composition record pushed by Garmin for [userId].
///
/// Queries the `garmin_health_data` table directly via Supabase (service-role
/// reads are gated by RLS on the authenticated user's JWT). Returns null when
/// Garmin is not connected, or no body-comp data has been received yet.

@ProviderFor(garminLastBodyComp)
const garminLastBodyCompProvider = GarminLastBodyCompFamily._();

/// Fetches the latest body composition record pushed by Garmin for [userId].
///
/// Queries the `garmin_health_data` table directly via Supabase (service-role
/// reads are gated by RLS on the authenticated user's JWT). Returns null when
/// Garmin is not connected, or no body-comp data has been received yet.

final class GarminLastBodyCompProvider
    extends
        $FunctionalProvider<
          AsyncValue<GarminBodyCompData?>,
          GarminBodyCompData?,
          FutureOr<GarminBodyCompData?>
        >
    with
        $FutureModifier<GarminBodyCompData?>,
        $FutureProvider<GarminBodyCompData?> {
  /// Fetches the latest body composition record pushed by Garmin for [userId].
  ///
  /// Queries the `garmin_health_data` table directly via Supabase (service-role
  /// reads are gated by RLS on the authenticated user's JWT). Returns null when
  /// Garmin is not connected, or no body-comp data has been received yet.
  const GarminLastBodyCompProvider._({
    required GarminLastBodyCompFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'garminLastBodyCompProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$garminLastBodyCompHash();

  @override
  String toString() {
    return r'garminLastBodyCompProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GarminBodyCompData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GarminBodyCompData?> create(Ref ref) {
    final argument = this.argument as String;
    return garminLastBodyComp(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GarminLastBodyCompProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$garminLastBodyCompHash() =>
    r'233cafa4713ba6984262d4bbf518a612bfda1a62';

/// Fetches the latest body composition record pushed by Garmin for [userId].
///
/// Queries the `garmin_health_data` table directly via Supabase (service-role
/// reads are gated by RLS on the authenticated user's JWT). Returns null when
/// Garmin is not connected, or no body-comp data has been received yet.

final class GarminLastBodyCompFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GarminBodyCompData?>, String> {
  const GarminLastBodyCompFamily._()
    : super(
        retry: null,
        name: r'garminLastBodyCompProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches the latest body composition record pushed by Garmin for [userId].
  ///
  /// Queries the `garmin_health_data` table directly via Supabase (service-role
  /// reads are gated by RLS on the authenticated user's JWT). Returns null when
  /// Garmin is not connected, or no body-comp data has been received yet.

  GarminLastBodyCompProvider call(String userId) =>
      GarminLastBodyCompProvider._(argument: userId, from: this);

  @override
  String toString() => r'garminLastBodyCompProvider';
}

/// Provider for the V.O2 API client (auth + workouts).

@ProviderFor(vdotApiClient)
const vdotApiClientProvider = VdotApiClientProvider._();

/// Provider for the V.O2 API client (auth + workouts).

final class VdotApiClientProvider
    extends $FunctionalProvider<VdotApiClient, VdotApiClient, VdotApiClient>
    with $Provider<VdotApiClient> {
  /// Provider for the V.O2 API client (auth + workouts).
  const VdotApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vdotApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vdotApiClientHash();

  @$internal
  @override
  $ProviderElement<VdotApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VdotApiClient create(Ref ref) {
    return vdotApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VdotApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VdotApiClient>(value),
    );
  }
}

String _$vdotApiClientHash() => r'e2d9cdd5402c6543ba6d640c4b9e1de8df4f41db';

/// Provider for the V.O2 OAuth service.

@ProviderFor(vdotOAuthService)
const vdotOAuthServiceProvider = VdotOAuthServiceProvider._();

/// Provider for the V.O2 OAuth service.

final class VdotOAuthServiceProvider
    extends
        $FunctionalProvider<
          VdotOAuthService,
          VdotOAuthService,
          VdotOAuthService
        >
    with $Provider<VdotOAuthService> {
  /// Provider for the V.O2 OAuth service.
  const VdotOAuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vdotOAuthServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vdotOAuthServiceHash();

  @$internal
  @override
  $ProviderElement<VdotOAuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VdotOAuthService create(Ref ref) {
    return vdotOAuthService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VdotOAuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VdotOAuthService>(value),
    );
  }
}

String _$vdotOAuthServiceHash() => r'faa21874a656d9965fa327ad809ca3a5418d783a';

/// Provider to get the V.O2 integration for a user.

@ProviderFor(vdotIntegration)
const vdotIntegrationProvider = VdotIntegrationFamily._();

/// Provider to get the V.O2 integration for a user.

final class VdotIntegrationProvider
    extends
        $FunctionalProvider<
          AsyncValue<IntegrationModel?>,
          IntegrationModel?,
          FutureOr<IntegrationModel?>
        >
    with
        $FutureModifier<IntegrationModel?>,
        $FutureProvider<IntegrationModel?> {
  /// Provider to get the V.O2 integration for a user.
  const VdotIntegrationProvider._({
    required VdotIntegrationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vdotIntegrationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vdotIntegrationHash();

  @override
  String toString() {
    return r'vdotIntegrationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<IntegrationModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<IntegrationModel?> create(Ref ref) {
    final argument = this.argument as String;
    return vdotIntegration(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VdotIntegrationProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vdotIntegrationHash() => r'975d16ac1b322c4ecd0067b3a9a31ef305aafab3';

/// Provider to get the V.O2 integration for a user.

final class VdotIntegrationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<IntegrationModel?>, String> {
  const VdotIntegrationFamily._()
    : super(
        retry: null,
        name: r'vdotIntegrationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get the V.O2 integration for a user.

  VdotIntegrationProvider call(String userId) =>
      VdotIntegrationProvider._(argument: userId, from: this);

  @override
  String toString() => r'vdotIntegrationProvider';
}

/// Provider to check whether V.O2 is connected for a user.

@ProviderFor(isVdotConnected)
const isVdotConnectedProvider = IsVdotConnectedFamily._();

/// Provider to check whether V.O2 is connected for a user.

final class IsVdotConnectedProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Provider to check whether V.O2 is connected for a user.
  const IsVdotConnectedProvider._({
    required IsVdotConnectedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isVdotConnectedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isVdotConnectedHash();

  @override
  String toString() {
    return r'isVdotConnectedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    final argument = this.argument as String;
    return isVdotConnected(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is IsVdotConnectedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isVdotConnectedHash() => r'48c55df8934b36d5a2baf40a26ecbda4fa83a053';

/// Provider to check whether V.O2 is connected for a user.

final class IsVdotConnectedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<bool>, String> {
  const IsVdotConnectedFamily._()
    : super(
        retry: null,
        name: r'isVdotConnectedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to check whether V.O2 is connected for a user.

  IsVdotConnectedProvider call(String userId) =>
      IsVdotConnectedProvider._(argument: userId, from: this);

  @override
  String toString() => r'isVdotConnectedProvider';
}

/// Provider for the V.O2 transformer (workout JSON → Activity).

@ProviderFor(vdotTransformer)
const vdotTransformerProvider = VdotTransformerProvider._();

/// Provider for the V.O2 transformer (workout JSON → Activity).

final class VdotTransformerProvider
    extends
        $FunctionalProvider<VdotTransformer, VdotTransformer, VdotTransformer>
    with $Provider<VdotTransformer> {
  /// Provider for the V.O2 transformer (workout JSON → Activity).
  const VdotTransformerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vdotTransformerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vdotTransformerHash();

  @$internal
  @override
  $ProviderElement<VdotTransformer> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VdotTransformer create(Ref ref) {
    return vdotTransformer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VdotTransformer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VdotTransformer>(value),
    );
  }
}

String _$vdotTransformerHash() => r'834b3198ea2c756a914b85d88a5bc88d634dbdf9';

/// Provider for the V.O2 sync service.

@ProviderFor(vdotSyncService)
const vdotSyncServiceProvider = VdotSyncServiceProvider._();

/// Provider for the V.O2 sync service.

final class VdotSyncServiceProvider
    extends
        $FunctionalProvider<VdotSyncService, VdotSyncService, VdotSyncService>
    with $Provider<VdotSyncService> {
  /// Provider for the V.O2 sync service.
  const VdotSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vdotSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vdotSyncServiceHash();

  @$internal
  @override
  $ProviderElement<VdotSyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VdotSyncService create(Ref ref) {
    return vdotSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VdotSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VdotSyncService>(value),
    );
  }
}

String _$vdotSyncServiceHash() => r'd5bd0a1549f8553754f5655fb2f91c55eadaaa3d';
