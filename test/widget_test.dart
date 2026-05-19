import 'package:flutter_test/flutter_test.dart';

import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';
import 'package:voice_driver_mobile/core/semantic/semantic_tree_builder.dart';

/// Лёгкий smoke-тест ядра — без поднятия UI и Hive (UI-тесты с бесконечными
/// анимациями зависают runner; они покрыты вручную при `flutter run`).
void main() {
  test('Парсер и построитель дерева работают вместе', () {
    final engine = RussianNlpEngine();
    const builder = SemanticTreeBuilder();
    final cmd = engine.parse('создай задачу купить хлеб на завтра');
    final tree = builder.build(
      rawText: 'создай задачу купить хлеб на завтра',
      normalizedText: engine.normalize('создай задачу купить хлеб на завтра'),
      command: cmd,
    );
    expect(tree.intentCode, 'create_task');
    expect(tree.nodeCount, greaterThan(3));
  });
}
