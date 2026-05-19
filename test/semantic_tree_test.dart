import 'package:flutter_test/flutter_test.dart';

import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';
import 'package:voice_driver_mobile/core/semantic/semantic_node.dart';
import 'package:voice_driver_mobile/core/semantic/semantic_tree_builder.dart';

void main() {
  final engine = RussianNlpEngine();
  const builder = SemanticTreeBuilder();

  SemanticTree treeFor(String text) {
    final normalized = engine.normalize(text);
    final cmd = engine.parse(text);
    return builder.build(
      rawText: text,
      normalizedText: normalized,
      command: cmd,
      tokens: normalized.split(' ').where((t) => t.isNotEmpty).toList(),
    );
  }

  group('SemanticTreeBuilder', () {
    test('create_task строит ROOT → ACTION → OBJECT(title) → MODIFIERS', () {
      final tree = treeFor('создай задачу купить хлеб на завтра');

      expect(tree.intentCode, 'create_task');
      expect(tree.root.type, SemanticNodeType.root);
      expect(tree.root.children.length, greaterThanOrEqualTo(2));

      final action = tree.root.children.firstWhere(
        (n) => n.type == SemanticNodeType.action,
      );
      expect(action.value, 'create_task');

      final object = tree.root.children.firstWhere(
        (n) => n.type == SemanticNodeType.object,
      );
      expect(object.label, 'задача');
      expect(object.children.any((c) => c.label.contains('хлеб')), isTrue);

      final modGroup = tree.root.children.firstWhere(
        (n) => n.type == SemanticNodeType.modifier,
      );
      final hasDate = modGroup.children.any((c) => c.label == 'дата');
      expect(hasDate, isTrue);
    });

    test('show_tasks с фильтром только важных строит модификатор priority', () {
      final tree = treeFor('покажи важные задачи');
      expect(tree.intentCode, 'show_tasks');

      final modGroup = tree.root.children.firstWhere(
        (n) => n.type == SemanticNodeType.modifier,
        orElse: () => SemanticNode(
          type: SemanticNodeType.modifier,
          label: 'none',
        ),
      );
      expect(
        modGroup.children.any((c) => c.label == 'приоритет'),
        isTrue,
      );
    });

    test('unknown добавляет дочерний узел "не распознано"', () {
      final tree = treeFor('абракадабра');
      expect(tree.intentCode, 'unknown');
      final hasUnknown = tree.root.children
          .any((c) => c.label.contains('не распознано'));
      expect(hasUnknown, isTrue);
    });

    test('статистика дерева адекватная', () {
      final tree = treeFor('создай задачу купить хлеб на завтра');
      expect(tree.nodeCount, greaterThanOrEqualTo(4));
      expect(tree.depth, greaterThanOrEqualTo(3));
      expect(tree.leafCount, greaterThanOrEqualTo(2));
    });

    test('navigate содержит target в OBJECT', () {
      final tree = treeFor('открой аналитику');
      expect(tree.intentCode, 'navigate');
      final object = tree.root.children
          .firstWhere((n) => n.type == SemanticNodeType.object);
      expect(object.children.any((c) => c.value == 'analytics'), isTrue);
    });
  });
}
