import 'dart:async';

import 'package:flutter/foundation.dart';

import '../pipeline/pipeline_event.dart';
import '../semantic/semantic_command_runner.dart';
import 'voice_feedback.dart';
import 'voice_service.dart';

/// Связывает микрофон, [SemanticCommandRunner] и TTS-ответ.
class VoiceCommandCoordinator {
  VoiceCommandCoordinator({
    required VoiceService voice,
    required SemanticCommandRunner runner,
  })  : _voice = voice,
        _runner = runner;

  final VoiceService _voice;
  final SemanticCommandRunner _runner;

  final ValueNotifier<bool> listening = ValueNotifier(false);
  final ValueNotifier<bool> processing = ValueNotifier(false);

  /// Live-транскрипция (частичные результаты STT).
  final ValueNotifier<String> partialTranscript = ValueNotifier('');

  /// Wake-word: фоновое прослушивание триггерной фразы.
  final ValueNotifier<bool> wakeWordActive = ValueNotifier(false);

  static const List<String> wakeWordTriggers = [
    'привет ассистент',
    'привет ассистент',
    'эй ассистент',
    'ассистент',
    'окей ассистент',
    'окей помощник',
    'привет помощник',
  ];

  bool _wakeWordMode = false;
  bool _wakeListening = false;
  Timer? _wakeRestartTimer;

  void Function()? onMicUnavailable;

  /// Snackbar / доп. UX после серии команд.
  void Function(List<RunOutcome> outcomes, String rawText)? onCommandsExecuted;

  /// Стрим событий пайплайна (для живого графа архитектуры).
  Stream<PipelineEvent> get pipelineEvents => _runner.eventBus.stream;

  void attachMicUnavailable(void Function() handler) {
    onMicUnavailable = handler;
  }

  Future<void> handlePointerDown() async {
    await _stopWakeListening();
    if (listening.value) return;
    listening.value = true;
    partialTranscript.value = '';

    final ok = await _voice.init();
    if (!ok) {
      listening.value = false;
      onMicUnavailable?.call();
      _scheduleWakeRestart();
      return;
    }

    try {
      await _voice.startListening(
        (text) {
          listening.value = false;
          unawaited(_runPipelineAndSpeak(text));
        },
        onPartial: (partial) {
          partialTranscript.value = partial;
        },
      );
    } catch (e, st) {
      debugPrint('[Voice] startListening failed: $e\n$st');
      listening.value = false;
      onMicUnavailable?.call();
      _scheduleWakeRestart();
    }
  }

  Future<void> handlePointerUp() async {
    await _voice.stopListening();
    listening.value = false;
    _scheduleWakeRestart();
  }

  Future<void> startSingleListening() async {
    await handlePointerDown();
  }

  Future<void> _runPipelineAndSpeak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await _voice.speak(VoiceFeedback.phraseFor('unknown'));
      _scheduleWakeRestart();
      return;
    }
    processing.value = true;
    try {
      final outcomes = await _runner.run(trimmed);
      onCommandsExecuted?.call(outcomes, trimmed);
      if (outcomes.isEmpty) {
        await _voice.speak(VoiceFeedback.phraseFor('unknown'));
        return;
      }
      final last = outcomes.last;
      final phrase = outcomes.length > 1
          ? 'Выполнено ${outcomes.length} команд: ${VoiceFeedback.phraseForResult(last.execution)}'
          : VoiceFeedback.phraseForResult(last.execution);
      await _voice.speak(phrase);
    } finally {
      processing.value = false;
      partialTranscript.value = '';
      _scheduleWakeRestart();
    }
  }

  // ── Wake-word режим ────────────────────────────────────────────────

  Future<void> enableWakeWord() async {
    if (_wakeWordMode) return;
    _wakeWordMode = true;
    wakeWordActive.value = true;
    final ok = await _voice.init();
    if (!ok) {
      _wakeWordMode = false;
      wakeWordActive.value = false;
      onMicUnavailable?.call();
      return;
    }
    await _startWakeCycle();
  }

  Future<void> disableWakeWord() async {
    _wakeWordMode = false;
    wakeWordActive.value = false;
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = null;
    await _stopWakeListening();
  }

  void _scheduleWakeRestart() {
    if (!_wakeWordMode) return;
    _wakeRestartTimer?.cancel();
    _wakeRestartTimer = Timer(const Duration(milliseconds: 700), () {
      if (_wakeWordMode && !listening.value && !processing.value) {
        unawaited(_startWakeCycle());
      }
    });
  }

  Future<void> _stopWakeListening() async {
    if (!_wakeListening) return;
    _wakeListening = false;
    try {
      await _voice.stopListening();
    } catch (_) {/* ignore */}
  }

  Future<void> _startWakeCycle() async {
    if (!_wakeWordMode || _wakeListening || listening.value) return;
    _wakeListening = true;
    try {
      await _voice.startListening(
        (text) async {
          _wakeListening = false;
          final lower = text.trim().toLowerCase();
          if (_containsWakeWord(lower)) {
            final rest = _stripWakeWord(lower);
            if (rest.isNotEmpty) {
              // Активация и сразу команда в одной фразе: «Ассистент, покажи задачи»
              unawaited(_runPipelineAndSpeak(rest));
              return;
            }
            // Активация без команды: реагируем «Слушаю» и стартуем активное слушание.
            await _voice.speak('Слушаю');
            await Future<void>.delayed(const Duration(milliseconds: 350));
            await handlePointerDown();
          } else {
            _scheduleWakeRestart();
          }
        },
        onPartial: (partial) {
          final lower = partial.toLowerCase();
          if (_containsWakeWord(lower)) {
            partialTranscript.value = partial;
          }
        },
      );
    } catch (e, st) {
      debugPrint('[WakeWord] start failed: $e\n$st');
      _wakeListening = false;
      _scheduleWakeRestart();
    }
  }

  bool _containsWakeWord(String lower) {
    for (final w in wakeWordTriggers) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  String _stripWakeWord(String text) {
    var s = text;
    for (final w in wakeWordTriggers) {
      final i = s.indexOf(w);
      if (i >= 0) {
        s = s.substring(i + w.length).trim();
        // Иногда после wake-слова идёт запятая или союз: «ассистент, покажи…»
        s = s.replaceFirst(RegExp(r'^[,\.\!\?]+\s*'), '').trim();
        return s;
      }
    }
    return s.trim();
  }

  void dispose() {
    _wakeRestartTimer?.cancel();
    _wakeWordMode = false;
    listening.dispose();
    processing.dispose();
    partialTranscript.dispose();
    wakeWordActive.dispose();
    unawaited(_voice.stopListening());
    unawaited(_runner.eventBus.dispose());
  }
}
