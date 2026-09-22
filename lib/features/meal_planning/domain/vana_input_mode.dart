/// How the athlete sent a message to Vana (mp-464 clause 7).
///
/// The server records it on the call row so the saving the fixed-label chips
/// make is measurable against the chip taps that still cost a turn. The
/// scripted opener is neither: Vana speaks first there, so no mode is sent.
///
/// It is a measurement, never a behaviour: nothing in the app or on the server
/// treats a tapped message differently from a typed one.
enum VanaInputMode {
  /// The athlete tapped a chip Vana offered (or a card's action that sends a
  /// message on its behalf).
  tap('tap'),

  /// The athlete typed it.
  typed('typed');

  const VanaInputMode(this.wire);

  /// The `input_mode` value on the wire.
  final String wire;
}
