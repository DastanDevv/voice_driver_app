import 'dart:async';

import 'package:flutter/foundation.dart';

import '../semantic/semantic_command.dart';
import '../semantic/semantic_command_runner.dart';
import 'voice_feedback.dart';
import 'voice_service.dart';

/// Связывает микрофон, [SemanticCommandRunner] и TTS-ответ; UI только жесты и индикатор.
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

  void Function()? onMicUnavailable;

  /// Snackbar / доп. UX после команды (unknown, низкая уверенность).
  void Function(SemanticCommand cmd, String rawText)? onCommandUx;

  void attachMicUnavailable(void Function() handler) {
    onMicUnavailable = handler;
  }

  Future<void> handlePointerDown() async {
    if (listening.value) return;
    listening.value = true;
    partialTranscript.value = '';

    final ok = await _voice.init();
    if (!ok) {
      listening.value = false;
      onMicUnavailable?.call();
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
    }
  }

  Future<void> handlePointerUp() async {
    await _voice.stopListening();
    listening.value = false;
  }

  Future<void> _runPipelineAndSpeak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await _voice.speak(VoiceFeedback.phraseFor('unknown'));
      return;
    }
    processing.value = true;
    try {
      final (cmd, result) = await _runner.run(trimmed);
      onCommandUx?.call(cmd, trimmed);
      final phrase = VoiceFeedback.phraseForResult(result);
      await _voice.speak(phrase);
    } finally {
      processing.value = false;
      partialTranscript.value = '';
    }
  }

  void dispose() {
    listening.dispose();
    processing.dispose();
    partialTranscript.dispose();
    unawaited(_voice.stopListening());
  }
}
