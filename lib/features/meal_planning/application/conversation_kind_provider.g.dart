// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_kind_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The kind of an existing Vana conversation, read from the server, for a
/// link that names the conversation but not its mode (`/vana?c=<id>`).
/// Null when the conversation is not the athlete's or does not exist; the
/// route then falls back to meal planning, as it always did
/// (testing-wave 134, Finding 118-004).

@ProviderFor(conversationKind)
const conversationKindProvider = ConversationKindFamily._();

/// The kind of an existing Vana conversation, read from the server, for a
/// link that names the conversation but not its mode (`/vana?c=<id>`).
/// Null when the conversation is not the athlete's or does not exist; the
/// route then falls back to meal planning, as it always did
/// (testing-wave 134, Finding 118-004).

final class ConversationKindProvider
    extends
        $FunctionalProvider<
          AsyncValue<VanaConversationKind?>,
          VanaConversationKind?,
          FutureOr<VanaConversationKind?>
        >
    with
        $FutureModifier<VanaConversationKind?>,
        $FutureProvider<VanaConversationKind?> {
  /// The kind of an existing Vana conversation, read from the server, for a
  /// link that names the conversation but not its mode (`/vana?c=<id>`).
  /// Null when the conversation is not the athlete's or does not exist; the
  /// route then falls back to meal planning, as it always did
  /// (testing-wave 134, Finding 118-004).
  const ConversationKindProvider._({
    required ConversationKindFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationKindProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationKindHash();

  @override
  String toString() {
    return r'conversationKindProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VanaConversationKind?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VanaConversationKind?> create(Ref ref) {
    final argument = this.argument as String;
    return conversationKind(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationKindProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationKindHash() => r'3c3976cf1325a5e3a3eee94943e6f3d54258e082';

/// The kind of an existing Vana conversation, read from the server, for a
/// link that names the conversation but not its mode (`/vana?c=<id>`).
/// Null when the conversation is not the athlete's or does not exist; the
/// route then falls back to meal planning, as it always did
/// (testing-wave 134, Finding 118-004).

final class ConversationKindFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VanaConversationKind?>, String> {
  const ConversationKindFamily._()
    : super(
        retry: null,
        name: r'conversationKindProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The kind of an existing Vana conversation, read from the server, for a
  /// link that names the conversation but not its mode (`/vana?c=<id>`).
  /// Null when the conversation is not the athlete's or does not exist; the
  /// route then falls back to meal planning, as it always did
  /// (testing-wave 134, Finding 118-004).

  ConversationKindProvider call(String id) =>
      ConversationKindProvider._(argument: id, from: this);

  @override
  String toString() => r'conversationKindProvider';
}
