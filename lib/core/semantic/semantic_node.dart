/// Тип узла семантического дерева.
///
/// Дерево строится из плоской команды: ROOT хранит общую структуру,
/// ACTION — глагольную часть (создать/удалить/...), OBJECT — именованную сущность
/// (задача, тема, экран), MODIFIER — атрибутивные уточнения (дата, приоритет, цель и т.д.).
enum SemanticNodeType {
  root,
  action,
  object,
  modifier,
  value,
}

/// Узел семантического дерева (рекурсивная структура).
///
/// Каждый узел знает:
///   - тип ([type]),
///   - метку для отображения ([label]),
///   - произвольную полезную нагрузку ([payload]) — например токены, lemma, raw-span,
///   - уверенность шага ([confidence]),
///   - вложенные узлы ([children]).
///
/// Используется как академически корректное «семантическое дерево»
/// для визуализации в NLP Lab и для исполнителя команд.
class SemanticNode {
  SemanticNode({
    required this.type,
    required this.label,
    this.value,
    this.confidence = 1.0,
    this.payload = const {},
    List<SemanticNode>? children,
  }) : children = children ?? <SemanticNode>[];

  final SemanticNodeType type;

  /// Человеко-читаемая метка (для UI).
  final String label;

  /// Опциональная «строковая» сущность (например, name задачи или дата как ключ).
  final String? value;

  /// Локальная уверенность узла (для будущей агрегации).
  final double confidence;

  /// Дополнительные данные узла (raw-span, токены, тип сущности).
  final Map<String, dynamic> payload;

  final List<SemanticNode> children;

  void addChild(SemanticNode node) => children.add(node);

  /// Подсчёт листьев для статистики дерева.
  int countLeaves() {
    if (children.isEmpty) return 1;
    var c = 0;
    for (final ch in children) {
      c += ch.countLeaves();
    }
    return c;
  }

  /// Глубина дерева (root = 1).
  int depth() {
    if (children.isEmpty) return 1;
    var maxD = 0;
    for (final ch in children) {
      final d = ch.depth();
      if (d > maxD) maxD = d;
    }
    return 1 + maxD;
  }

  /// Общее число узлов.
  int totalNodes() {
    var n = 1;
    for (final ch in children) {
      n += ch.totalNodes();
    }
    return n;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'label': label,
      if (value != null) 'value': value,
      'confidence': confidence,
      if (payload.isNotEmpty) 'payload': payload,
      if (children.isNotEmpty)
        'children': children.map((c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() => 'SemanticNode(${type.name}, "$label")';
}

/// Корневой контейнер семантического дерева одной команды.
///
/// В отличие от «плоской» [SemanticCommand], здесь хранится иерархия,
/// raw-text и нормализованный текст — для отрисовки в NLP-лаборатории.
class SemanticTree {
  SemanticTree({
    required this.rawText,
    required this.normalizedText,
    required this.intentCode,
    required this.confidence,
    required this.root,
    this.tokens = const [],
  });

  final String rawText;
  final String normalizedText;
  final String intentCode;
  final double confidence;

  /// Корневой узел (как правило типа [SemanticNodeType.root]).
  final SemanticNode root;

  /// Токены нормализованной фразы (для подсветки в UI).
  final List<String> tokens;

  int get nodeCount => root.totalNodes();
  int get leafCount => root.countLeaves();
  int get depth => root.depth();

  Map<String, dynamic> toJson() => {
        'rawText': rawText,
        'normalizedText': normalizedText,
        'intentCode': intentCode,
        'confidence': confidence,
        'tokens': tokens,
        'root': root.toJson(),
      };
}
