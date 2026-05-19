import 'dart:async';

/// Этапы обработки голосовой команды (узлы архитектурного графа).
enum PipelineStage {
  microphone,
  speechToText,
  splitter,
  nlpParser,
  contextManager,
  semanticTree,
  executor,
  textToSpeech,
}

/// Событие активации этапа (для подсветки в живом графе).
class PipelineEvent {
  PipelineEvent({
    required this.stage,
    required this.at,
    this.payload,
  });

  final PipelineStage stage;
  final DateTime at;
  final String? payload;
}

/// Шина событий пайплайна. UI подписывается, ядро эмиттит.
class PipelineEventBus {
  final StreamController<PipelineEvent> _controller =
      StreamController<PipelineEvent>.broadcast();

  Stream<PipelineEvent> get stream => _controller.stream;

  void emit(PipelineStage stage, {String? payload}) {
    if (_controller.isClosed) return;
    _controller.add(
      PipelineEvent(stage: stage, at: DateTime.now(), payload: payload),
    );
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
