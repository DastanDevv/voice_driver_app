import '../semantic/command_executor.dart';

/// Тексты озвучки после выполнения команды (динамические + статические).
abstract final class VoiceFeedback {
  /// Динамическая озвучка на основе результата выполнения.
  static String phraseForResult(ExecutionResult result) {
    if (result.message != null) return result.message!;
    return phraseFor(result.intentCode);
  }

  /// Статическая озвучка по коду намерения (fallback).
  static String phraseFor(String intentCode) {
    switch (intentCode) {
      case 'create_task':
        return 'Задача добавлена';
      case 'show_tasks':
        return 'Показаны задачи';
      case 'complete_task':
        return 'Задача отмечена выполненной';
      case 'delete_task':
        return 'Задача удалена';
      case 'search_task':
        return 'Результаты поиска показаны';
      case 'count_tasks':
        return 'Подсчёт задач';
      case 'clear_completed':
        return 'Выполненные задачи удалены';
      case 'help':
        return 'Я умею создавать, показывать, выполнять, удалять, искать, считать задачи, менять тему и навигацию.';
      case 'navigate':
        return 'Переключаю экран';
      case 'theme_toggle':
        return 'Тема изменена';
      case 'undo':
        return 'Действие отменено';
      case 'unknown':
      default:
        return 'Не удалось распознать команду';
    }
  }
}
