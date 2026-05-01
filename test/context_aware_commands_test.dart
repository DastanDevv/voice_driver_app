import 'package:flutter_test/flutter_test.dart';
import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';
import 'package:voice_driver_mobile/core/semantic/context_manager.dart';

void main() {
  final nlp = RussianNlpEngine();

  test('1. покажи задачи → только важные', () {
    final cm = ContextManager();
    var r = cm.applyContext(nlp.parse('покажи задачи'));
    expect(r.intentCode, 'show_tasks');

    r = cm.applyContext(nlp.parse('только важные'));
    expect(r.intentCode, 'show_tasks');
    expect(r.entities['priority'], 'high');
  });

  test('2. покажи задачи → на завтра', () {
    final cm = ContextManager();
    cm.applyContext(nlp.parse('покажи задачи'));
    final r = cm.applyContext(nlp.parse('на завтра'));
    expect(r.intentCode, 'show_tasks');
    expect(r.entities['date'], 'tomorrow');
  });

  test('3. создай задачу купить хлеб → завтра', () {
    final cm = ContextManager();
    cm.applyContext(nlp.parse('создай задачу купить хлеб'));
    final r = cm.applyContext(nlp.parse('завтра'));
    expect(r.intentCode, 'create_task');
    expect(r.entities['title'], 'купить хлеб');
    expect(r.entities['date'], 'tomorrow');
  });

  test('4. покажи задачи → создай задачу тест (сброс контекста)', () {
    final cm = ContextManager();
    cm.applyContext(nlp.parse('покажи задачи'));
    final r = cm.applyContext(nlp.parse('создай задачу тест'));
    expect(r.intentCode, 'create_task');
    expect(r.entities['title'], 'тест');
    expect(r.entities.containsKey('priority'), isFalse);
  });
}
