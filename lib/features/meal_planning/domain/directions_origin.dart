/// `DirectionsOrigin` in `contracts.ts` — provenance of `MealDetail.methodSteps`.
enum DirectionsOrigin {
  source('source'),
  altSource('alt_source'),
  aiGenerated('ai_generated'),
  assemblySimple('assembly_simple');

  const DirectionsOrigin(this.wire);

  final String wire;

  static DirectionsOrigin? fromWire(String? value) {
    if (value == null) return null;
    for (final v in DirectionsOrigin.values) {
      if (v.wire == value) return v;
    }
    return null;
  }
}
