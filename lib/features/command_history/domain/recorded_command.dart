import 'package:equatable/equatable.dart';

/// Запись для экрана «История команд» (защита / демо).
class RecordedCommand extends Equatable {
  const RecordedCommand({
    required this.rawText,
    required this.intentCode,
    required this.entities,
    required this.confidence,
    required this.at,
    this.treeJson,
  });

  final String rawText;
  final String intentCode;
  final Map<String, dynamic> entities;
  final double confidence;
  final DateTime at;

  /// Сериализованное семантическое дерево (для просмотра в истории).
  final Map<String, dynamic>? treeJson;

  @override
  List<Object?> get props => [rawText, intentCode, entities, confidence, at, treeJson];
}
