import 'package:equatable/equatable.dart';

/// Запись для экрана «История команд» (защита / демо).
class RecordedCommand extends Equatable {
  const RecordedCommand({
    required this.rawText,
    required this.intentCode,
    required this.entities,
    required this.confidence,
    required this.at,
  });

  final String rawText;
  final String intentCode;
  final Map<String, dynamic> entities;
  final double confidence;
  final DateTime at;

  @override
  List<Object?> get props => [rawText, intentCode, entities, confidence, at];
}
