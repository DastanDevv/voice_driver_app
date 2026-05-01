/// Результат построения семантического дерева (плоское представление).
///
/// `intentCode` — внутренний код намерения (например `show_tasks`).
class SemanticCommand {
  const SemanticCommand({
    required this.intentCode,
    required this.entities,
    this.confidence = 1,
  });

  final String intentCode;

  /// Извлечённые параметры (фильтры, заголовок задачи и т.д.).
  final Map<String, dynamic> entities;

  final double confidence;
}
