import 'package:flutter/foundation.dart';

import '../nlp/russian_nlp_engine.dart';
import 'command_executor.dart';
import 'context_manager.dart';
import 'semantic_command.dart';

/// После выполнения команды (например запись в историю защиты).
typedef OnCommandResolved = void Function(
    String rawText, SemanticCommand resolved);

/// Склейка: текст → parse → [ContextManager.applyContext] → execute.
///
/// UI вызывает только [run]; контекст и логика — в core.
class SemanticCommandRunner {
  SemanticCommandRunner({
    RussianNlpEngine? nlp,
    required CommandExecutor executor,
    ContextManager? contextManager,
    this.onCommandResolved,
  })  : _nlp = nlp ?? RussianNlpEngine(),
        _executor = executor,
        _contextManager = contextManager ?? ContextManager();

  final RussianNlpEngine _nlp;
  final CommandExecutor _executor;
  final ContextManager _contextManager;
  final OnCommandResolved? onCommandResolved;

  /// Текст для демо-кнопки (как в ТЗ).
  static const String demoPhrase = 'покажи задачи';

  /// Расширенный сценарий для кнопки «Демо команды» (защита).
  static const List<String> demoPhrases = [
    'покажи задачи',
    'только важные',
    'создай задачу купить хлеб завтра',
    'сколько задач',
    'найди задачу хлеб',
    'покажи задачи на сегодня',
    'помощь',
    'открой аналитику',
    'включи тёмную тему',
    'включи светлую тему',
    'перейди в лабораторию',
  ];

  /// Возвращает команду после контекста (для TTS и тестов).
  /// Executor вызывается асинхронно; resolved-команда возвращается сразу.
  Future<(SemanticCommand, ExecutionResult)> run(String rawText) async {
    final trimmed = rawText.trim();
    debugPrint('[VoicePipeline] ввод: "$trimmed"');

    final parsed = _nlp.parse(trimmed);
    final resolved = _contextManager.applyContext(parsed);
    final result = await _executor.execute(resolved);
    onCommandResolved?.call(trimmed, resolved);
    return (resolved, result);
  }

  /// Синхронный parse-only (для NLP Lab визуализации).
  SemanticCommand parseOnly(String rawText) {
    final trimmed = rawText.trim();
    final parsed = _nlp.parse(trimmed);
    return _contextManager.applyContext(parsed);
  }
}
