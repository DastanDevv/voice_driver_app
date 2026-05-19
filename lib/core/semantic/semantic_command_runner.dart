import 'package:flutter/foundation.dart';

import '../nlp/command_splitter.dart';
import '../nlp/russian_nlp_engine.dart';
import '../pipeline/pipeline_event.dart';
import 'command_executor.dart';
import 'context_manager.dart';
import 'semantic_command.dart';
import 'semantic_node.dart';
import 'semantic_tree_builder.dart';

typedef OnCommandResolved = void Function(
  String rawText,
  SemanticCommand resolved,
  SemanticTree tree,
);

/// Полный результат одного прогона: финальная команда + дерево + результат executor'а.
class RunOutcome {
  RunOutcome({
    required this.rawText,
    required this.command,
    required this.tree,
    required this.execution,
  });

  final String rawText;
  final SemanticCommand command;
  final SemanticTree tree;
  final ExecutionResult execution;
}

/// Склейка: текст → split → parse → context → tree → execute.
///
/// UI вызывает [run]; контекст и логика — в core.
/// Поддерживает составные фразы («создай задачу X и удали задачу Y»).
class SemanticCommandRunner {
  SemanticCommandRunner({
    RussianNlpEngine? nlp,
    required CommandExecutor executor,
    ContextManager? contextManager,
    CommandSplitter? splitter,
    SemanticTreeBuilder? treeBuilder,
    PipelineEventBus? eventBus,
    this.onCommandResolved,
  })  : _nlp = nlp ?? RussianNlpEngine(),
        _executor = executor,
        _contextManager = contextManager ?? ContextManager(),
        _splitter = splitter ?? const CommandSplitter(),
        _treeBuilder = treeBuilder ?? const SemanticTreeBuilder(),
        eventBus = eventBus ?? PipelineEventBus();

  final RussianNlpEngine _nlp;
  final CommandExecutor _executor;
  final ContextManager _contextManager;
  final CommandSplitter _splitter;
  final SemanticTreeBuilder _treeBuilder;

  /// Шина событий для живого графа архитектуры.
  final PipelineEventBus eventBus;

  final OnCommandResolved? onCommandResolved;

  static const String demoPhrase = 'покажи задачи';

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

  /// Запустить обработку фразы. Возвращает список outcome — по одному на сегмент
  /// (для составных запросов через «и потом», «а также» и т.д.).
  Future<List<RunOutcome>> run(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) return const [];

    debugPrint('[VoicePipeline] ввод: "$trimmed"');
    eventBus.emit(PipelineStage.speechToText, payload: trimmed);

    final segments = _splitter.split(trimmed);
    if (segments.length > 1) {
      eventBus.emit(
        PipelineStage.splitter,
        payload: 'сегментов: ${segments.length}',
      );
    }

    final outcomes = <RunOutcome>[];
    for (final segment in segments) {
      final outcome = await _runSingle(segment);
      outcomes.add(outcome);
    }

    return outcomes;
  }

  /// Возвращает только дерево (для NLP Lab визуализации, без побочных эффектов).
  SemanticTree parseTree(String rawText) {
    final trimmed = rawText.trim();
    final normalized = _nlp.normalize(trimmed);
    final parsed = _nlp.parse(trimmed);
    final resolved = _contextManager.applyContext(parsed);
    return _treeBuilder.build(
      rawText: trimmed,
      normalizedText: normalized,
      command: resolved,
      tokens: normalized.split(' ').where((t) => t.isNotEmpty).toList(),
    );
  }

  Future<RunOutcome> _runSingle(String segment) async {
    eventBus.emit(PipelineStage.nlpParser, payload: segment);
    final normalized = _nlp.normalize(segment);
    final parsed = _nlp.parse(segment);

    eventBus.emit(
      PipelineStage.contextManager,
      payload: parsed.intentCode,
    );
    final resolved = _contextManager.applyContext(parsed);

    final tree = _treeBuilder.build(
      rawText: segment,
      normalizedText: normalized,
      command: resolved,
      tokens: normalized.split(' ').where((t) => t.isNotEmpty).toList(),
    );
    eventBus.emit(
      PipelineStage.semanticTree,
      payload: 'узлов: ${tree.nodeCount}',
    );

    eventBus.emit(PipelineStage.executor, payload: resolved.intentCode);
    final result = await _executor.execute(resolved);

    onCommandResolved?.call(segment, resolved, tree);

    return RunOutcome(
      rawText: segment,
      command: resolved,
      tree: tree,
      execution: result,
    );
  }
}
