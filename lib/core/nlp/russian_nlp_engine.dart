import 'package:flutter/foundation.dart';

import '../semantic/semantic_command.dart';

/// Локальный разбор русских фраз (V3): расширенные интенты, числительные, поиск по имени.
class RussianNlpEngine {
  RussianNlpEngine();

  static final RegExp _createTaskRe = RegExp(
    r'(?:создай|создайте|добавь|добавьте)(?:\s+мне)?\s+задач(?:у|а)\s+(.+)',
    caseSensitive: false,
  );

  static final RegExp _delayHoursRe = RegExp(
    r'через\s+(\d+|один|одну|два|две|три|четыре|пять|шесть|семь|восемь|девять|десять)\s+(час|часа|часов)(?=\s|$)',
  );

  static final RegExp _searchTaskRe = RegExp(
    r'(?:найди|найдите|поищи|поищите|ищи)\s+(?:задач(?:у|а|и)\s+)?(.+)',
    caseSensitive: false,
  );

  static final RegExp _deleteTaskWithNameRe = RegExp(
    r'(?:удали|удалите|убери|уберите)\s+задач(?:у|а|и)\s+(.+)',
    caseSensitive: false,
  );

  static final RegExp _completeTaskWithNameRe = RegExp(
    r'(?:выполни|выполните|отметь|отметьте|заверши|завершите)\s+задач(?:у|а|и)\s+(.+)',
    caseSensitive: false,
  );

  static const List<String> _showRoots = [
    'покажи', 'покажите', 'открой', 'откройте', 'выведи', 'выведите',
  ];

  static const List<String> _completeRoots = [
    'выполни', 'выполните', 'отметь', 'отметьте', 'заверши', 'завершите',
  ];

  static const List<String> _deleteRoots = [
    'удали', 'удалите', 'убери', 'уберите',
  ];

  static const List<String> _helpRoots = [
    'помощь', 'помоги', 'помогите', 'что ты умеешь', 'что умеешь',
    'какие команды', 'список команд',
  ];

  static const List<String> _countRoots = [
    'сколько задач', 'сколько осталось', 'количество задач', 'число задач',
    'посчитай задачи', 'подсчитай задачи',
  ];

  static const List<String> _clearCompletedRoots = [
    'очисти выполненные', 'удали выполненные', 'убери выполненные',
    'очисти завершенные', 'удали завершенные', 'убери завершенные',
    'очисти готовые',
  ];

  static const Map<String, String> _navigateTargets = {
    'аналитик': 'analytics',
    'статистик': 'analytics',
    'лаборатори': 'nlp_lab',
    'nlp': 'nlp_lab',
    'задач': 'tasks',
    'задания': 'tasks',
    'истори': 'history',
    'команд': 'history',
  };

  static const List<String> _navigateRoots = [
    'открой', 'откройте', 'перейди', 'перейдите', 'покажи', 'покажите',
    'переключи', 'переключись',
  ];

  static const List<String> _darkThemeRoots = [
    'темную тему', 'темная тема', 'ночной режим', 'ночную тему',
    'темный режим',
  ];

  static const List<String> _lightThemeRoots = [
    'светлую тему', 'светлая тема', 'дневной режим', 'светлую тему',
    'светлый режим',
  ];

  static const List<String> _undoRoots = [
    'отмена', 'отмени', 'отменить', 'верни назад', 'верни обратно',
    'назад',
  ];

  static const Set<String> _titleNoiseTokens = {
    'создай', 'создайте', 'добавь', 'добавьте', 'мне',
    'задачу', 'задача', 'задачи', 'задач', 'список', 'на',
  };

  static const Map<String, int> _wordNumbers = {
    'один': 1, 'одну': 1, 'два': 2, 'две': 2, 'три': 3,
    'четыре': 4, 'пять': 5, 'шесть': 6, 'семь': 7,
    'восемь': 8, 'девять': 9, 'десять': 10,
  };

  String normalize(String raw) {
    var s = raw.trim().toLowerCase().replaceAll('ё', 'е');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s.trim();
  }

  bool get isReady => true;

  static const Map<String, Map<String, dynamic>> _shortContextPhrases = {
    'только важные': {'priority': 'high'},
    'только срочно': {'priority': 'high'},
    'на завтра': {'date': 'tomorrow'},
    'на сегодня': {'date': 'today'},
    'на послезавтра': {'date': 'day_after_tomorrow'},
    'сегодня': {'date': 'today'},
    'завтра': {'date': 'tomorrow'},
    'послезавтра': {'date': 'day_after_tomorrow'},
  };

  SemanticCommand? _tryShortContextFragment(String normalized) {
    if (normalized.length > 48) return null;
    final payload = _shortContextPhrases[normalized];
    if (payload == null) return null;
    return SemanticCommand(
      intentCode: 'unknown',
      entities: Map<String, dynamic>.from(payload),
      confidence: 0.6,
    );
  }

  SemanticCommand parse(String text) {
    final normalized = normalize(text);

    final fragment = _tryShortContextFragment(normalized);
    if (fragment != null) {
      _log(normalized, fragment);
      return fragment;
    }

    final cmd = _tryHelp(normalized)
        ?? _tryUndo(normalized)
        ?? _tryThemeToggle(normalized)
        ?? _tryNavigate(normalized)
        ?? _tryClearCompleted(normalized)
        ?? _tryCountTasks(normalized)
        ?? _trySearchTask(normalized)
        ?? _tryDeleteTaskByName(normalized)
        ?? _tryCompleteTaskByName(normalized)
        ?? _tryCreateTask(normalized)
        ?? _tryDeleteTask(normalized)
        ?? _tryCompleteTask(normalized)
        ?? _tryShowTasks(normalized)
        ?? const SemanticCommand(
            intentCode: 'unknown',
            entities: <String, dynamic>{},
            confidence: 0,
          );

    _log(normalized, cmd);
    return cmd;
  }

  void _log(String normalized, SemanticCommand cmd) {
    debugPrint('[ParserV3] text: $normalized');
    debugPrint('[ParserV3] intent: ${cmd.intentCode}');
    debugPrint('[ParserV3] entities: ${cmd.entities}');
    debugPrint('[ParserV3] confidence: ${cmd.confidence}');
  }

  // ─── Date / priority extraction ──────────────────────────────────

  Map<String, dynamic> extractDate(String normalizedText) {
    final s = normalizedText;
    final out = <String, dynamic>{};

    final delay = _delayHoursRe.firstMatch(s);
    if (delay != null) {
      final raw = delay.group(1)!;
      final hours = int.tryParse(raw) ?? _wordNumbers[raw] ?? 0;
      if (hours > 0) out['delay_hours'] = hours;
    }

    if (s.contains('на следующей неделе')) {
      out['date'] = 'next_week';
    } else if (s.contains('на послезавтра')) {
      out['date'] = 'day_after_tomorrow';
    } else if (s.contains('на завтра')) {
      out['date'] = 'tomorrow';
    } else if (s.contains('на сегодня')) {
      out['date'] = 'today';
    } else if (s.contains('послезавтра')) {
      out['date'] = 'day_after_tomorrow';
    } else if (s.contains('сегодня')) {
      out['date'] = 'today';
    } else if (s.contains('завтра')) {
      out['date'] = 'tomorrow';
    }

    return out;
  }

  void extractPriority(String normalizedText, Map<String, dynamic> entities) {
    if (normalizedText.contains('важн') ||
        normalizedText.contains('срочн')) {
      entities['priority'] = 'high';
    }
  }

  String extractTitle(String rawSegment, Map<String, dynamic> entityHints) {
    var t = rawSegment.trim();
    t = t.replaceAll(_delayHoursRe, ' ');
    t = _stripDatePhrases(t, entityHints);
    t = _stripPriorityTokens(t);
    t = _stripKnownCommandTokens(t);
    return normalize(t);
  }

  // ─── Intent: create_task ─────────────────────────────────────────

  SemanticCommand? _tryCreateTask(String s) {
    if (!s.contains('создай') && !s.contains('добавь')) return null;
    if (!s.contains('задач')) return null;

    final match = _createTaskRe.firstMatch(s);
    late final String rawTitle;
    var confidence = 0.9;

    if (match != null) {
      rawTitle = match.group(1)?.trim() ?? '';
    } else {
      final fb = _fallbackCreateTitle(s);
      if (fb == null) return null;
      rawTitle = fb;
      confidence = 0.6;
    }

    if (rawTitle.isEmpty) return _unknown();

    final entities = <String, dynamic>{};
    entities.addAll(extractDate(s));
    extractPriority(s, entities);

    final title = extractTitle(rawTitle, entities);
    if (title.isEmpty) return _unknown();

    entities['title'] = title;
    return SemanticCommand(
      intentCode: 'create_task',
      entities: entities,
      confidence: confidence,
    );
  }

  String? _fallbackCreateTitle(String s) {
    const needles = ['задачу ', 'задача ', 'задачи ', 'задач '];
    for (final n in needles) {
      final i = s.indexOf(n);
      if (i >= 0) {
        final tail = s.substring(i + n.length).trim();
        if (tail.isNotEmpty) return tail;
      }
    }
    return null;
  }

  // ─── Intent: complete_task (with optional name) ──────────────────

  SemanticCommand? _tryCompleteTaskByName(String s) {
    final match = _completeTaskWithNameRe.firstMatch(s);
    if (match == null) return null;
    final query = _cleanTaskQuery(match.group(1)?.trim() ?? '');
    if (query.isEmpty) return null;
    return SemanticCommand(
      intentCode: 'complete_task',
      entities: <String, dynamic>{'title_query': query},
      confidence: 0.85,
    );
  }

  SemanticCommand? _tryCompleteTask(String s) {
    for (final root in _completeRoots) {
      if (s.contains(root)) {
        return const SemanticCommand(
          intentCode: 'complete_task',
          entities: <String, dynamic>{},
          confidence: 0.9,
        );
      }
    }
    return null;
  }

  // ─── Intent: delete_task (with optional name) ────────────────────

  SemanticCommand? _tryDeleteTaskByName(String s) {
    final match = _deleteTaskWithNameRe.firstMatch(s);
    if (match == null) return null;
    final query = _cleanTaskQuery(match.group(1)?.trim() ?? '');
    if (query.isEmpty) return null;
    return SemanticCommand(
      intentCode: 'delete_task',
      entities: <String, dynamic>{'title_query': query},
      confidence: 0.85,
    );
  }

  SemanticCommand? _tryDeleteTask(String s) {
    final hasDeleteVerb = _containsAnyRoot(s, _deleteRoots);
    if (!hasDeleteVerb) return null;
    if (s.contains('задач') || s.contains('последн')) {
      return const SemanticCommand(
        intentCode: 'delete_task',
        entities: <String, dynamic>{},
        confidence: 0.9,
      );
    }
    return null;
  }

  // ─── Intent: show_tasks ──────────────────────────────────────────

  SemanticCommand? _tryShowTasks(String s) {
    final hasShowVerb = _containsAnyRoot(s, _showRoots);
    final hasTaskNoun = s.contains('задач') || s.contains('задача');
    if (!hasShowVerb || !hasTaskNoun) return null;

    final entities = <String, dynamic>{};
    entities.addAll(extractDate(s));
    extractPriority(s, entities);

    return SemanticCommand(
      intentCode: 'show_tasks',
      entities: entities,
      confidence: 0.9,
    );
  }

  // ─── Intent: search_task ─────────────────────────────────────────

  SemanticCommand? _trySearchTask(String s) {
    final match = _searchTaskRe.firstMatch(s);
    if (match == null) return null;
    final query = normalize(match.group(1)?.trim() ?? '');
    if (query.isEmpty) return null;
    return SemanticCommand(
      intentCode: 'search_task',
      entities: <String, dynamic>{'query': query},
      confidence: 0.9,
    );
  }

  // ─── Intent: count_tasks ─────────────────────────────────────────

  SemanticCommand? _tryCountTasks(String s) {
    for (final root in _countRoots) {
      if (s.contains(root)) {
        return const SemanticCommand(
          intentCode: 'count_tasks',
          entities: <String, dynamic>{},
          confidence: 0.95,
        );
      }
    }
    return null;
  }

  // ─── Intent: help ────────────────────────────────────────────────

  SemanticCommand? _tryHelp(String s) {
    for (final root in _helpRoots) {
      if (s.contains(root)) {
        return const SemanticCommand(
          intentCode: 'help',
          entities: <String, dynamic>{},
          confidence: 1.0,
        );
      }
    }
    return null;
  }

  // ─── Intent: clear_completed ─────────────────────────────────────

  SemanticCommand? _tryClearCompleted(String s) {
    for (final root in _clearCompletedRoots) {
      if (s.contains(root)) {
        return const SemanticCommand(
          intentCode: 'clear_completed',
          entities: <String, dynamic>{},
          confidence: 0.9,
        );
      }
    }
    return null;
  }

  // ─── Intent: navigate ─────────────────────────────────────────────

  SemanticCommand? _tryNavigate(String s) {
    final hasNavVerb = _containsAnyRoot(s, _navigateRoots);
    if (!hasNavVerb) return null;
    if (s.contains('задач') && !s.contains('аналитик') && !s.contains('лаборатори')) {
      return null;
    }
    for (final entry in _navigateTargets.entries) {
      if (s.contains(entry.key)) {
        return SemanticCommand(
          intentCode: 'navigate',
          entities: <String, dynamic>{'target': entry.value},
          confidence: 0.95,
        );
      }
    }
    return null;
  }

  // ─── Intent: theme_toggle ────────────────────────────────────────

  SemanticCommand? _tryThemeToggle(String s) {
    if (s.contains('включи') || s.contains('переключи') ||
        s.contains('смени') || s.contains('поставь') || s.contains('сделай')) {
      for (final root in _darkThemeRoots) {
        if (s.contains(root)) {
          return const SemanticCommand(
            intentCode: 'theme_toggle',
            entities: <String, dynamic>{'theme': 'dark'},
            confidence: 0.95,
          );
        }
      }
      for (final root in _lightThemeRoots) {
        if (s.contains(root)) {
          return const SemanticCommand(
            intentCode: 'theme_toggle',
            entities: <String, dynamic>{'theme': 'light'},
            confidence: 0.95,
          );
        }
      }
    }
    return null;
  }

  // ─── Intent: undo ────────────────────────────────────────────────

  SemanticCommand? _tryUndo(String s) {
    for (final root in _undoRoots) {
      if (s == root || s.startsWith('$root ') || s.endsWith(' $root')) {
        return const SemanticCommand(
          intentCode: 'undo',
          entities: <String, dynamic>{},
          confidence: 0.9,
        );
      }
    }
    return null;
  }

  // ─── Helpers ─────────────────────────────────────────────────────

  bool _containsAnyRoot(String s, List<String> roots) {
    for (final r in roots) {
      if (s.contains(r)) return true;
    }
    return false;
  }

  String _cleanTaskQuery(String raw) {
    var s = raw;
    s = _stripDatePhrases(s, extractDate(s));
    s = _stripPriorityTokens(s);
    return normalize(s);
  }

  static SemanticCommand _unknown() => const SemanticCommand(
        intentCode: 'unknown',
        entities: <String, dynamic>{},
        confidence: 0,
      );

  static String _stripDatePhrases(String t, Map<String, dynamic> e) {
    var s = t;
    switch (e['date']) {
      case 'tomorrow':
        s = _removePhrase(s, 'на завтра');
        s = _removePhrase(s, 'завтра');
      case 'today':
        s = _removePhrase(s, 'на сегодня');
        s = _removePhrase(s, 'сегодня');
      case 'day_after_tomorrow':
        s = _removePhrase(s, 'на послезавтра');
        s = _removePhrase(s, 'послезавтра');
      case 'next_week':
        s = _removePhrase(s, 'на следующей неделе');
    }
    return s;
  }

  static String _removePhrase(String source, String phrase) =>
      source.replaceAll(phrase, ' ');

  static String _stripPriorityTokens(String t) {
    final parts = t.split(' ').where((w) {
      if (w.isEmpty) return false;
      if (w.contains('важн')) return false;
      if (w.contains('срочн')) return false;
      return true;
    });
    return parts.join(' ');
  }

  static String _stripKnownCommandTokens(String t) {
    final parts = t.split(' ').where((w) {
      if (w.isEmpty) return false;
      return !_titleNoiseTokens.contains(w);
    });
    return parts.join(' ');
  }
}
