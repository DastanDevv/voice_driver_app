/// Абстракция STT + TTS (реализация в [VoiceServiceImpl]).
abstract class VoiceService {
  Future<bool> init();

  /// Распознавание; [onResult] вызывается при финальной гипотезе (непустой текст).
  /// [onPartial] — опционально, промежуточные результаты для live-транскрипции.
  Future<void> startListening(
    void Function(String text) onResult, {
    void Function(String partial)? onPartial,
  });

  Future<void> stopListening();

  Future<void> speak(String text);
}
