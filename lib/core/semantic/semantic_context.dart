/// Снимок последнего успешно разрешённого намерения (для многошаговых команд).
class SemanticContext {
  const SemanticContext({
    this.lastIntent,
    this.lastEntities = const {},
  });

  final String? lastIntent;
  final Map<String, dynamic> lastEntities;

  SemanticContext copyWith({
    String? lastIntent,
    Map<String, dynamic>? lastEntities,
  }) {
    return SemanticContext(
      lastIntent: lastIntent ?? this.lastIntent,
      lastEntities: lastEntities ?? this.lastEntities,
    );
  }
}
