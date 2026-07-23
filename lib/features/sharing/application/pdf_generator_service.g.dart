// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pdf_generator_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pdfGeneratorService)
const pdfGeneratorServiceProvider = PdfGeneratorServiceProvider._();

final class PdfGeneratorServiceProvider
    extends
        $FunctionalProvider<
          PdfGeneratorService,
          PdfGeneratorService,
          PdfGeneratorService
        >
    with $Provider<PdfGeneratorService> {
  const PdfGeneratorServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pdfGeneratorServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pdfGeneratorServiceHash();

  @$internal
  @override
  $ProviderElement<PdfGeneratorService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PdfGeneratorService create(Ref ref) {
    return pdfGeneratorService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PdfGeneratorService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PdfGeneratorService>(value),
    );
  }
}

String _$pdfGeneratorServiceHash() =>
    r'4cc6f101435cfe91f8f1a653a0a0e45f51e26cf2';
