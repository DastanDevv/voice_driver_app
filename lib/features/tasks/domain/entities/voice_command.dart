import 'package:equatable/equatable.dart';

import 'voice_intent_type.dart';

/// Зафиксированная голосовая команда: распознанный текст + намерение + сущности.
///
/// Сущности (`entities`) соответствуют «листьям» семантического дерева:
/// например `priority`, `date`, `time`, `taskTitle` — заполняются парсером на шаге 3.
class VoiceCommand extends Equatable {
  const VoiceCommand({
    required this.id,
    required this.recognizedText,
    required this.intent,
    required this.entities,
    required this.timestamp,
  });

  final String id;
  final String recognizedText;
  final VoiceIntentType intent;

  /// Структурированные извлечённые параметры (фильтры, фрагменты текста и т.д.).
  final Map<String, Object?> entities;

  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id,
        recognizedText,
        intent,
        entities,
        timestamp,
      ];
}
