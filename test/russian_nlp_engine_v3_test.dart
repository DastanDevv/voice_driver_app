import 'package:flutter_test/flutter_test.dart';
import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';

void main() {
  final engine = RussianNlpEngine();

  group('V2 intents (backward compat)', () {
    test('create_task — создай задачу купить молоко завтра', () {
      final c = engine.parse('создай задачу купить молоко завтра');
      expect(c.intentCode, 'create_task');
      expect(c.confidence, 0.9);
      expect(c.entities['title'], 'купить молоко');
      expect(c.entities['date'], 'tomorrow');
    });

    test('show_tasks — покажи важные задачи', () {
      final c = engine.parse('покажи важные задачи');
      expect(c.intentCode, 'show_tasks');
      expect(c.confidence, 0.9);
      expect(c.entities['priority'], 'high');
    });

    test('show_tasks — покажи задачи на сегодня', () {
      final c = engine.parse('покажи задачи на сегодня');
      expect(c.intentCode, 'show_tasks');
      expect(c.entities['date'], 'today');
    });

    test('create_task — через 2 часа', () {
      final c = engine.parse('создай задачу позвонить маме через 2 часа');
      expect(c.intentCode, 'create_task');
      expect(c.entities['title'], 'позвонить маме');
      expect(c.entities['delay_hours'], 2);
    });

    test('complete_task — отметь задачу выполненной (name match)', () {
      final c = engine.parse('отметь задачу выполненной');
      expect(c.intentCode, 'complete_task');
      expect(c.confidence, 0.85);
      expect(c.entities['title_query'], isNotNull);
    });

    test('complete_task — выполни (без имени)', () {
      final c = engine.parse('выполни');
      expect(c.intentCode, 'complete_task');
      expect(c.confidence, 0.9);
    });

    test('show_tasks — комбинированные фильтры', () {
      final c = engine.parse('покажи важные задачи на завтра');
      expect(c.intentCode, 'show_tasks');
      expect(c.entities['priority'], 'high');
      expect(c.entities['date'], 'tomorrow');
    });
  });

  group('V3: delete_task', () {
    test('удали задачу (без имени)', () {
      final c = engine.parse('удали задачу');
      expect(c.intentCode, 'delete_task');
      expect(c.confidence, 0.9);
    });

    test('удали задачу купить хлеб (по имени)', () {
      final c = engine.parse('удали задачу купить хлеб');
      expect(c.intentCode, 'delete_task');
      expect(c.entities['title_query'], contains('купить хлеб'));
    });
  });

  group('V3: search_task', () {
    test('найди задачу презентацию', () {
      final c = engine.parse('найди задачу презентацию');
      expect(c.intentCode, 'search_task');
      expect(c.entities['query'], contains('презентацию'));
    });
  });

  group('V3: count_tasks', () {
    test('сколько задач', () {
      final c = engine.parse('сколько задач');
      expect(c.intentCode, 'count_tasks');
      expect(c.confidence, 0.95);
    });
  });

  group('V3: help', () {
    test('помощь', () {
      final c = engine.parse('помощь');
      expect(c.intentCode, 'help');
      expect(c.confidence, 1.0);
    });

    test('что ты умеешь', () {
      final c = engine.parse('что ты умеешь');
      expect(c.intentCode, 'help');
    });
  });

  group('V3: clear_completed', () {
    test('очисти выполненные', () {
      final c = engine.parse('очисти выполненные');
      expect(c.intentCode, 'clear_completed');
    });
  });

  group('V3: complete_task by name', () {
    test('выполни задачу купить хлеб', () {
      final c = engine.parse('выполни задачу купить хлеб');
      expect(c.intentCode, 'complete_task');
      expect(c.entities['title_query'], contains('купить хлеб'));
    });
  });

  group('V3: word numbers', () {
    test('через два часа', () {
      final c = engine.parse('создай задачу позвонить через два часа');
      expect(c.intentCode, 'create_task');
      expect(c.entities['delay_hours'], 2);
    });

    test('через пять часов', () {
      final c = engine.parse('создай задачу встреча через пять часов');
      expect(c.intentCode, 'create_task');
      expect(c.entities['delay_hours'], 5);
    });
  });

  group('V3: navigate', () {
    test('открой аналитику', () {
      final c = engine.parse('открой аналитику');
      expect(c.intentCode, 'navigate');
      expect(c.entities['target'], 'analytics');
    });

    test('перейди в лабораторию', () {
      final c = engine.parse('перейди в лабораторию');
      expect(c.intentCode, 'navigate');
      expect(c.entities['target'], 'nlp_lab');
    });

    test('открой историю', () {
      final c = engine.parse('открой историю');
      expect(c.intentCode, 'navigate');
      expect(c.entities['target'], 'history');
    });
  });

  group('V3: theme_toggle', () {
    test('включи тёмную тему', () {
      final c = engine.parse('включи тёмную тему');
      expect(c.intentCode, 'theme_toggle');
      expect(c.entities['theme'], 'dark');
    });

    test('включи светлую тему', () {
      final c = engine.parse('включи светлую тему');
      expect(c.intentCode, 'theme_toggle');
      expect(c.entities['theme'], 'light');
    });
  });

  group('V3: undo', () {
    test('отмена', () {
      final c = engine.parse('отмена');
      expect(c.intentCode, 'undo');
    });

    test('верни назад', () {
      final c = engine.parse('верни назад');
      expect(c.intentCode, 'undo');
    });
  });
}
