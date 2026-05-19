/// Разбивает длинную составную фразу на отдельные команды по конъюнкциям.
///
/// Это позволяет пользователю говорить:
///   «создай задачу купить хлеб и удали задачу презентацию а потом покажи задачи»
/// — и приложение исполняет три команды последовательно.
class CommandSplitter {
  const CommandSplitter();

  static final RegExp _separator = RegExp(
    r'\s+(?:и\s+потом|и\s+затем|а\s+потом|а\s+затем|потом|затем|после\s+чего|а\s+также|также|и\s+ещё|и\s+еще)\s+',
    caseSensitive: false,
  );

  /// Простое «и» как разделитель используется только когда фраза похожа на
  /// последовательность команд — иначе оно может быть частью одного действия.
  static final RegExp _andSeparator = RegExp(r'\s+и\s+', caseSensitive: false);

  /// Глагольные корни, по которым угадываем границу новой команды.
  static const List<String> _verbStems = [
    'создай', 'создайте', 'добавь', 'добавьте',
    'покажи', 'покажите', 'открой', 'откройте',
    'выполни', 'выполните', 'заверши', 'завершите',
    'удали', 'удалите', 'убери', 'уберите',
    'найди', 'найдите', 'поищи',
    'отмени', 'отменить', 'отмена',
    'сколько', 'посчитай', 'подсчитай',
    'очисти', 'переключи', 'включи',
    'перейди', 'перейдите',
  ];

  List<String> split(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final parts = trimmed.split(_separator);
    final out = <String>[];
    for (final p in parts) {
      out.addAll(_smartSplitOnAnd(p.trim()));
    }
    return out.where((s) => s.trim().isNotEmpty).toList();
  }

  /// Делит фразу по «и» только если правая часть начинается с глагольной формы
  /// (то есть это явно новая команда, а не часть существительного «хлеб и молоко»).
  List<String> _smartSplitOnAnd(String text) {
    final lower = text.toLowerCase();
    final matches = _andSeparator.allMatches(lower).toList();
    if (matches.isEmpty) return [text];

    final segments = <String>[];
    var start = 0;
    for (final m in matches) {
      final tail = lower.substring(m.end);
      if (_startsWithVerb(tail)) {
        segments.add(text.substring(start, m.start).trim());
        start = m.end;
      }
    }
    segments.add(text.substring(start).trim());
    return segments.where((s) => s.isNotEmpty).toList();
  }

  bool _startsWithVerb(String text) {
    for (final v in _verbStems) {
      if (text.startsWith('$v ') || text == v) return true;
    }
    return false;
  }
}
