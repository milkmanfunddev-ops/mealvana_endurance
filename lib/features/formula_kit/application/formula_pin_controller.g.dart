// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formula_pin_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the active-pin set for the current user. Card / detail widgets read
/// `pinnedTemplateIds.contains(id)` to render the icon state; `togglePin`
/// mutates Drift (and triggers a non-blocking Supabase upload via the
/// repository) then updates state optimistically.
///
/// Failures during the local Drift write revert the optimistic flip and
/// surface to the UI via the AsyncNotifier error channel. Drift writes are
/// fast and reliable, so the failure case is rare — but it's handled so the
/// icon never lies about persisted state.

@ProviderFor(FormulaPinController)
const formulaPinControllerProvider = FormulaPinControllerProvider._();

/// Owns the active-pin set for the current user. Card / detail widgets read
/// `pinnedTemplateIds.contains(id)` to render the icon state; `togglePin`
/// mutates Drift (and triggers a non-blocking Supabase upload via the
/// repository) then updates state optimistically.
///
/// Failures during the local Drift write revert the optimistic flip and
/// surface to the UI via the AsyncNotifier error channel. Drift writes are
/// fast and reliable, so the failure case is rare — but it's handled so the
/// icon never lies about persisted state.
final class FormulaPinControllerProvider
    extends $AsyncNotifierProvider<FormulaPinController, FormulaPinState> {
  /// Owns the active-pin set for the current user. Card / detail widgets read
  /// `pinnedTemplateIds.contains(id)` to render the icon state; `togglePin`
  /// mutates Drift (and triggers a non-blocking Supabase upload via the
  /// repository) then updates state optimistically.
  ///
  /// Failures during the local Drift write revert the optimistic flip and
  /// surface to the UI via the AsyncNotifier error channel. Drift writes are
  /// fast and reliable, so the failure case is rare — but it's handled so the
  /// icon never lies about persisted state.
  const FormulaPinControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formulaPinControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formulaPinControllerHash();

  @$internal
  @override
  FormulaPinController create() => FormulaPinController();
}

String _$formulaPinControllerHash() =>
    r'd9407f745c7205a5b4e96e2eb59a871943b224f4';

/// Owns the active-pin set for the current user. Card / detail widgets read
/// `pinnedTemplateIds.contains(id)` to render the icon state; `togglePin`
/// mutates Drift (and triggers a non-blocking Supabase upload via the
/// repository) then updates state optimistically.
///
/// Failures during the local Drift write revert the optimistic flip and
/// surface to the UI via the AsyncNotifier error channel. Drift writes are
/// fast and reliable, so the failure case is rare — but it's handled so the
/// icon never lies about persisted state.

abstract class _$FormulaPinController extends $AsyncNotifier<FormulaPinState> {
  FutureOr<FormulaPinState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<FormulaPinState>, FormulaPinState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FormulaPinState>, FormulaPinState>,
              AsyncValue<FormulaPinState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
