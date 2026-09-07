/// `Memory.kind` in `contracts.ts` (`user_memories.kind`).
enum MemoryKind {
  preference('preference'),
  constraint('constraint'),
  pattern('pattern'),
  episode('episode'),
  setting('setting');

  const MemoryKind(this.wire);

  final String wire;

  static MemoryKind? fromWire(String? value) {
    if (value == null) return null;
    for (final v in MemoryKind.values) {
      if (v.wire == value) return v;
    }
    return null;
  }

  static MemoryKind requireWire(String? value) =>
      fromWire(value) ?? (throw FormatException('Unknown MemoryKind "$value"'));
}
