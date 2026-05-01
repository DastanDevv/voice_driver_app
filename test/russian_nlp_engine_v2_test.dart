import 'package:flutter_test/flutter_test.dart';
import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';

void main() {
  final engine = RussianNlpEngine();

  test('1. создай задачу купить молоко завтра', () {
    final c = engine.parse('создай задачу купить молоко завтра');
    expect(c.intentCode, 'create_task');
    expect(c.confidence, 0.9);
    expect(c.entities['title'], 'купить молоко');
    expect(c.entities['date'], 'tomorrow');
  });

  test('2. покажи важные задачи', () {
    final c = engine.parse('покажи важные задачи');
    expect(c.intentCode, 'show_tasks');
    expect(c.confidence, 0.9);
    expect(c.entities['priority'], 'high');
  });

  test('3. покажи задачи на сегодня', () {
    final c = engine.parse('покажи задачи на сегодня');
    expect(c.intentCode, 'show_tasks');
    expect(c.entities['date'], 'today');
  });

  test('4. создай задачу позвонить маме через 2 часа', () {
    final c = engine.parse('создай задачу позвонить маме через 2 часа');
    expect(c.intentCode, 'create_task');
    expect(c.entities['title'], 'позвонить маме');
    expect(c.entities['delay_hours'], 2);
  });

  test('5. отметь задачу выполненной (V3: name match)', () {
    final c = engine.parse('отметь задачу выполненной');
    expect(c.intentCode, 'complete_task');
    expect(c.confidence, 0.85);
    expect(c.entities['title_query'], 'выполненной');
  });

  test('покажи важные задачи на завтра (комбинированные фильтры)', () {
    final c = engine.parse('покажи важные задачи на завтра');
    expect(c.intentCode, 'show_tasks');
    expect(c.entities['priority'], 'high');
    expect(c.entities['date'], 'tomorrow');
  });
}
