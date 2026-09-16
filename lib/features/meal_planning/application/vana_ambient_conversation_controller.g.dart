// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_ambient_conversation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The wall clock the ambient day is read from. Overridden in tests.

@ProviderFor(vanaClock)
const vanaClockProvider = VanaClockProvider._();

/// The wall clock the ambient day is read from. Overridden in tests.

final class VanaClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The wall clock the ambient day is read from. Overridden in tests.
  const VanaClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return vanaClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$vanaClockHash() => r'8ea0cfb6354214b8bafdc1215fba11ffead9b96f';

/// The ambient conversation behind the Vana sheet: one general conversation
/// per person per day (vana-sheet spec VS-5).
///
/// The value is today's conversation id, or null before the day's first sheet
/// has one. It is read at open time (`ref.refresh(...future)`), so a sheet
/// opened after midnight starts a new conversation even if the app never
/// restarted. The sheet holds the id it opened with for its whole life and
/// calls [adopt] once the server names a new conversation.
///
/// It also says when that conversation is idle (mp-288): when the sheet
/// closes ([sheetClosed]), when the app goes to the background, and when a
/// new conversation takes its place (a new day, or the server naming a
/// different one). The server writes the conversation's episode once, so the
/// next opener has it without waiting. Kept alive so the background signal
/// fires with no sheet open.
///
/// Every entry point that continues the day (the launcher, its full-screen
/// button, the Plan tab's note card, a moment tap) opens through [openToday]
/// (mp-275 clause 1). Only the unnamed general conversation it arms can move
/// the pointer; a conversation started new has its own key
/// ([vanaNewConversationKey]) and never does.

@ProviderFor(VanaAmbientConversation)
const vanaAmbientConversationProvider = VanaAmbientConversationProvider._();

/// The ambient conversation behind the Vana sheet: one general conversation
/// per person per day (vana-sheet spec VS-5).
///
/// The value is today's conversation id, or null before the day's first sheet
/// has one. It is read at open time (`ref.refresh(...future)`), so a sheet
/// opened after midnight starts a new conversation even if the app never
/// restarted. The sheet holds the id it opened with for its whole life and
/// calls [adopt] once the server names a new conversation.
///
/// It also says when that conversation is idle (mp-288): when the sheet
/// closes ([sheetClosed]), when the app goes to the background, and when a
/// new conversation takes its place (a new day, or the server naming a
/// different one). The server writes the conversation's episode once, so the
/// next opener has it without waiting. Kept alive so the background signal
/// fires with no sheet open.
///
/// Every entry point that continues the day (the launcher, its full-screen
/// button, the Plan tab's note card, a moment tap) opens through [openToday]
/// (mp-275 clause 1). Only the unnamed general conversation it arms can move
/// the pointer; a conversation started new has its own key
/// ([vanaNewConversationKey]) and never does.
final class VanaAmbientConversationProvider
    extends $AsyncNotifierProvider<VanaAmbientConversation, String?> {
  /// The ambient conversation behind the Vana sheet: one general conversation
  /// per person per day (vana-sheet spec VS-5).
  ///
  /// The value is today's conversation id, or null before the day's first sheet
  /// has one. It is read at open time (`ref.refresh(...future)`), so a sheet
  /// opened after midnight starts a new conversation even if the app never
  /// restarted. The sheet holds the id it opened with for its whole life and
  /// calls [adopt] once the server names a new conversation.
  ///
  /// It also says when that conversation is idle (mp-288): when the sheet
  /// closes ([sheetClosed]), when the app goes to the background, and when a
  /// new conversation takes its place (a new day, or the server naming a
  /// different one). The server writes the conversation's episode once, so the
  /// next opener has it without waiting. Kept alive so the background signal
  /// fires with no sheet open.
  ///
  /// Every entry point that continues the day (the launcher, its full-screen
  /// button, the Plan tab's note card, a moment tap) opens through [openToday]
  /// (mp-275 clause 1). Only the unnamed general conversation it arms can move
  /// the pointer; a conversation started new has its own key
  /// ([vanaNewConversationKey]) and never does.
  const VanaAmbientConversationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaAmbientConversationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaAmbientConversationHash();

  @$internal
  @override
  VanaAmbientConversation create() => VanaAmbientConversation();
}

String _$vanaAmbientConversationHash() =>
    r'7f860dd83da3533926ea888f36e7b5a551b3cedc';

/// The ambient conversation behind the Vana sheet: one general conversation
/// per person per day (vana-sheet spec VS-5).
///
/// The value is today's conversation id, or null before the day's first sheet
/// has one. It is read at open time (`ref.refresh(...future)`), so a sheet
/// opened after midnight starts a new conversation even if the app never
/// restarted. The sheet holds the id it opened with for its whole life and
/// calls [adopt] once the server names a new conversation.
///
/// It also says when that conversation is idle (mp-288): when the sheet
/// closes ([sheetClosed]), when the app goes to the background, and when a
/// new conversation takes its place (a new day, or the server naming a
/// different one). The server writes the conversation's episode once, so the
/// next opener has it without waiting. Kept alive so the background signal
/// fires with no sheet open.
///
/// Every entry point that continues the day (the launcher, its full-screen
/// button, the Plan tab's note card, a moment tap) opens through [openToday]
/// (mp-275 clause 1). Only the unnamed general conversation it arms can move
/// the pointer; a conversation started new has its own key
/// ([vanaNewConversationKey]) and never does.

abstract class _$VanaAmbientConversation extends $AsyncNotifier<String?> {
  FutureOr<String?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<String?>, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String?>, String?>,
              AsyncValue<String?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
