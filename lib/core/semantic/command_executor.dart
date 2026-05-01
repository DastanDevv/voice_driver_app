import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/tasks/presentation/cubit/task_cubit.dart';
import 'semantic_command.dart';

/// Результат выполнения команды (для динамических TTS-ответов).
class ExecutionResult {
  const ExecutionResult({
    required this.intentCode,
    this.message,
    this.data = const {},
  });

  final String intentCode;
  final String? message;
  final Map<String, dynamic> data;
}

/// Выполнение семантической команды через [TaskCubit] (без UI).
class CommandExecutor {
  CommandExecutor(this._taskCubit);

  final TaskCubit _taskCubit;

  Future<ExecutionResult> execute(SemanticCommand command) async {
    switch (command.intentCode) {
      case 'show_tasks':
        return _executeShowTasks(command);
      case 'create_task':
        return _executeCreateTask(command);
      case 'complete_task':
        return _executeCompleteTask(command);
      case 'delete_task':
        return _executeDeleteTask(command);
      case 'search_task':
        return _executeSearchTask(command);
      case 'count_tasks':
        return _executeCountTasks();
      case 'clear_completed':
        return _executeClearCompleted();
      case 'help':
        return ExecutionResult(
          intentCode: 'help',
          message: 'Я умею: создавать задачи, показывать, выполнять, удалять, '
              'искать, считать, переключать тему и навигацию голосом.',
        );
      case 'navigate':
        return ExecutionResult(
          intentCode: 'navigate',
          data: {'target': command.entities['target']},
        );
      case 'theme_toggle':
        return ExecutionResult(
          intentCode: 'theme_toggle',
          data: {'theme': command.entities['theme']},
        );
      case 'undo':
        return const ExecutionResult(intentCode: 'undo');
      case 'unknown':
      default:
        return const ExecutionResult(intentCode: 'unknown');
    }
  }

  Future<ExecutionResult> _executeShowTasks(SemanticCommand command) async {
    final e = command.entities;
    final hasPriority = e['priority'] == 'high';
    final dk = e['date'];
    final hasDate = dk is String && dk.isNotEmpty;

    if (hasPriority || hasDate) {
      final date = hasDate ? _calendarDayForDateKey(dk) : null;
      await _taskCubit.filterTasks(
        priority: hasPriority ? 'high' : null,
        date: date,
      );
    } else {
      await _taskCubit.loadTasks();
    }
    return const ExecutionResult(intentCode: 'show_tasks');
  }

  Future<ExecutionResult> _executeCreateTask(SemanticCommand command) async {
    final e = command.entities;
    final title = e['title'];
    if (title is! String || title.trim().isEmpty) {
      return const ExecutionResult(intentCode: 'unknown');
    }

    final dueAt = _resolveDueAt(e);
    final priority = e['priority'] == 'high' ? 'high' : null;

    debugPrint('[Executor] create_task: dueAt=$dueAt, priority=$priority');

    await _taskCubit.addTask(title.trim(), dueAt: dueAt, priority: priority);
    return ExecutionResult(
      intentCode: 'create_task',
      data: {'title': title.trim()},
    );
  }

  Future<ExecutionResult> _executeCompleteTask(SemanticCommand command) async {
    final query = command.entities['title_query'];
    if (query is String && query.isNotEmpty) {
      final found = await _taskCubit.findAndComplete(query);
      if (!found) {
        return ExecutionResult(
          intentCode: 'complete_task',
          message: 'Задача «$query» не найдена',
          data: {'found': false},
        );
      }
      return ExecutionResult(
        intentCode: 'complete_task',
        data: {'found': true, 'query': query},
      );
    }
    _taskCubit.toggleLastTask();
    return const ExecutionResult(intentCode: 'complete_task');
  }

  Future<ExecutionResult> _executeDeleteTask(SemanticCommand command) async {
    final query = command.entities['title_query'];
    if (query is String && query.isNotEmpty) {
      final found = await _taskCubit.findAndDelete(query);
      if (!found) {
        return ExecutionResult(
          intentCode: 'delete_task',
          message: 'Задача «$query» не найдена',
          data: {'found': false},
        );
      }
      return ExecutionResult(
        intentCode: 'delete_task',
        data: {'found': true, 'query': query},
      );
    }
    await _taskCubit.deleteLastTask();
    return const ExecutionResult(intentCode: 'delete_task');
  }

  Future<ExecutionResult> _executeSearchTask(SemanticCommand command) async {
    final query = command.entities['query'];
    if (query is! String || query.isEmpty) {
      return const ExecutionResult(intentCode: 'unknown');
    }
    await _taskCubit.searchTasks(query);
    return ExecutionResult(
      intentCode: 'search_task',
      data: {'query': query},
    );
  }

  Future<ExecutionResult> _executeCountTasks() async {
    final counts = await _taskCubit.countTasks();
    final msg = 'Всего ${counts.total}: ${counts.active} активных, '
        '${counts.completed} выполненных.';
    return ExecutionResult(
      intentCode: 'count_tasks',
      message: msg,
      data: {
        'total': counts.total,
        'active': counts.active,
        'completed': counts.completed,
      },
    );
  }

  Future<ExecutionResult> _executeClearCompleted() async {
    final count = await _taskCubit.deleteCompleted();
    final msg = count > 0
        ? 'Удалено $count выполненных задач.'
        : 'Нет выполненных задач для удаления.';
    return ExecutionResult(
      intentCode: 'clear_completed',
      message: msg,
      data: {'deleted_count': count},
    );
  }

  static DateTime? _calendarDayForDateKey(String key) {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    switch (key) {
      case 'today':
        return startToday;
      case 'tomorrow':
        return startToday.add(const Duration(days: 1));
      case 'day_after_tomorrow':
        return startToday.add(const Duration(days: 2));
      case 'next_week':
        final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
        return startToday.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
      default:
        return null;
    }
  }

  static DateTime? _resolveDueAt(Map<String, dynamic> entities) {
    final delayRaw = entities['delay_hours'];
    int? delayHours;
    if (delayRaw is int) {
      delayHours = delayRaw;
    } else if (delayRaw is num) {
      delayHours = delayRaw.toInt();
    }
    if (delayHours != null && delayHours > 0) {
      return DateTime.now().add(Duration(hours: delayHours));
    }

    final dateKey = entities['date'];
    if (dateKey is String) {
      return _calendarDayForDateKey(dateKey);
    }
    return null;
  }
}
