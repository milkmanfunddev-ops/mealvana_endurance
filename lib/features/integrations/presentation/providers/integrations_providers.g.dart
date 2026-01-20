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
    r'4a07e1df7f594071ba023f8ebacb33ac8a309e0d';

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
    r'33791283b35be4de459a4ea916ac881bf97619a1';

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
    r'5777e7c9be73cd48d5094da30971b420104c8755';

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
    r'ac95d519150287fd3af08c5de03a02b9b38e1f4e';

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
    r'952bb7f47f5283d8ec30b91898f107261bf83740';

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
