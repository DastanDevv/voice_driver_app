import 'semantic_command.dart';
import 'semantic_node.dart';

/// Строит иерархическое [SemanticTree] из плоской [SemanticCommand].
///
/// Это и есть центральная идея диплома — «анализ семантического дерева».
/// Плоский результат парсера разворачивается в дерево ACTION → OBJECT → MODIFIERS,
/// что соответствует семантической структуре команды.
class SemanticTreeBuilder {
  const SemanticTreeBuilder();

  SemanticTree build({
    required String rawText,
    required String normalizedText,
    required SemanticCommand command,
    List<String> tokens = const [],
  }) {
    final root = SemanticNode(
      type: SemanticNodeType.root,
      label: 'Команда',
      confidence: command.confidence,
      payload: {'intent': command.intentCode},
    );

    final spec = _intentSpec(command.intentCode);

    final action = SemanticNode(
      type: SemanticNodeType.action,
      label: spec.actionLabel,
      value: command.intentCode,
      confidence: command.confidence,
      payload: {'intent': command.intentCode},
    );
    root.addChild(action);

    if (spec.objectLabel != null) {
      final object = SemanticNode(
        type: SemanticNodeType.object,
        label: spec.objectLabel!,
      );
      _attachObjectChildren(object, command, spec);
      root.addChild(object);
    }

    final modifiers = _buildModifierChildren(command, spec);
    if (modifiers.isNotEmpty) {
      final modGroup = SemanticNode(
        type: SemanticNodeType.modifier,
        label: 'Модификаторы',
        payload: {'count': modifiers.length},
      );
      for (final m in modifiers) {
        modGroup.addChild(m);
      }
      root.addChild(modGroup);
    }

    if (command.intentCode == 'unknown') {
      root.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: 'не распознано',
          confidence: 0,
        ),
      );
    }

    return SemanticTree(
      rawText: rawText,
      normalizedText: normalizedText,
      intentCode: command.intentCode,
      confidence: command.confidence,
      tokens: tokens,
      root: root,
    );
  }

  void _attachObjectChildren(
    SemanticNode object,
    SemanticCommand command,
    _IntentSpec spec,
  ) {
    final e = command.entities;

    final title = e['title'];
    if (title is String && title.isNotEmpty) {
      object.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: '«$title»',
          value: title,
          payload: {'field': 'title'},
        ),
      );
    }

    final query = e['title_query'];
    if (query is String && query.isNotEmpty) {
      object.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: 'содержит «$query»',
          value: query,
          payload: {'field': 'title_query'},
        ),
      );
    }

    final freeQuery = e['query'];
    if (freeQuery is String && freeQuery.isNotEmpty) {
      object.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: 'запрос «$freeQuery»',
          value: freeQuery,
          payload: {'field': 'query'},
        ),
      );
    }

    final target = e['target'];
    if (target is String && target.isNotEmpty) {
      object.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: spec.targetLabel(target),
          value: target,
          payload: {'field': 'target'},
        ),
      );
    }

    final theme = e['theme'];
    if (theme is String && theme.isNotEmpty) {
      object.addChild(
        SemanticNode(
          type: SemanticNodeType.value,
          label: theme == 'dark' ? 'тёмная тема' : 'светлая тема',
          value: theme,
          payload: {'field': 'theme'},
        ),
      );
    }
  }

  List<SemanticNode> _buildModifierChildren(
    SemanticCommand command,
    _IntentSpec spec,
  ) {
    final e = command.entities;
    final out = <SemanticNode>[];

    final date = e['date'];
    if (date is String && date.isNotEmpty) {
      out.add(
        SemanticNode(
          type: SemanticNodeType.modifier,
          label: 'дата',
          payload: {'kind': 'date'},
          children: [
            SemanticNode(
              type: SemanticNodeType.value,
              label: _dateLabel(date),
              value: date,
            ),
          ],
        ),
      );
    }

    final delay = e['delay_hours'];
    if (delay is num && delay > 0) {
      out.add(
        SemanticNode(
          type: SemanticNodeType.modifier,
          label: 'через',
          payload: {'kind': 'delay_hours'},
          children: [
            SemanticNode(
              type: SemanticNodeType.value,
              label: '$delay ч',
              value: '$delay',
            ),
          ],
        ),
      );
    }

    final priority = e['priority'];
    if (priority is String && priority.isNotEmpty) {
      out.add(
        SemanticNode(
          type: SemanticNodeType.modifier,
          label: 'приоритет',
          payload: {'kind': 'priority'},
          children: [
            SemanticNode(
              type: SemanticNodeType.value,
              label: priority == 'high' ? 'высокий' : priority,
              value: priority,
            ),
          ],
        ),
      );
    }

    if (spec.implicitFilter != null) {
      out.add(
        SemanticNode(
          type: SemanticNodeType.modifier,
          label: spec.implicitFilter!,
          payload: {'kind': 'implicit'},
        ),
      );
    }

    return out;
  }

  static String _dateLabel(String key) {
    switch (key) {
      case 'today':
        return 'сегодня';
      case 'tomorrow':
        return 'завтра';
      case 'day_after_tomorrow':
        return 'послезавтра';
      case 'next_week':
        return 'на след. неделе';
      default:
        return key;
    }
  }

  static _IntentSpec _intentSpec(String intent) {
    switch (intent) {
      case 'create_task':
        return const _IntentSpec(
          actionLabel: 'создать',
          objectLabel: 'задача',
        );
      case 'show_tasks':
        return const _IntentSpec(
          actionLabel: 'показать',
          objectLabel: 'задачи',
        );
      case 'complete_task':
        return const _IntentSpec(
          actionLabel: 'выполнить',
          objectLabel: 'задача',
        );
      case 'delete_task':
        return const _IntentSpec(
          actionLabel: 'удалить',
          objectLabel: 'задача',
        );
      case 'search_task':
        return const _IntentSpec(
          actionLabel: 'найти',
          objectLabel: 'задача',
        );
      case 'count_tasks':
        return const _IntentSpec(
          actionLabel: 'подсчитать',
          objectLabel: 'задачи',
        );
      case 'clear_completed':
        return const _IntentSpec(
          actionLabel: 'очистить',
          objectLabel: 'задачи',
          implicitFilter: 'статус: выполнено',
        );
      case 'help':
        return const _IntentSpec(actionLabel: 'помощь');
      case 'navigate':
        return _IntentSpec(
          actionLabel: 'перейти',
          objectLabel: 'экран',
          targetLabel: (t) {
            switch (t) {
              case 'tasks':
                return 'Задачи';
              case 'analytics':
                return 'Аналитика';
              case 'nlp_lab':
                return 'NLP Лаборатория';
              case 'history':
                return 'История';
              case 'chat':
                return 'Чат';
              case 'architecture':
                return 'Архитектура';
              default:
                return t;
            }
          },
        );
      case 'theme_toggle':
        return const _IntentSpec(
          actionLabel: 'переключить',
          objectLabel: 'тема',
        );
      case 'undo':
        return const _IntentSpec(actionLabel: 'отменить');
      case 'unknown':
      default:
        return const _IntentSpec(actionLabel: 'не распознано');
    }
  }
}

class _IntentSpec {
  const _IntentSpec({
    required this.actionLabel,
    this.objectLabel,
    this.implicitFilter,
    this.targetLabel = _passthroughTarget,
  });

  final String actionLabel;
  final String? objectLabel;
  final String? implicitFilter;
  final String Function(String) targetLabel;
}

String _passthroughTarget(String s) => s;
