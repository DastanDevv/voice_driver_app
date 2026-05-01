import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  TaskCubit(this._repository) : super(const TaskState());

  final TaskRepository _repository;

  String? _activePriorityFilter;
  DateTime? _activeDateFilter;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Task> _applyFilters(List<Task> all) {
    var list = List<Task>.from(all);
    if (_activePriorityFilter == 'high') {
      list = list.where((t) => t.priority == 'high').toList();
    }
    if (_activeDateFilter != null) {
      final day = _activeDateFilter!;
      list = list.where((t) {
        if (t.dueAt == null) return false;
        return _sameCalendarDay(_dateOnly(t.dueAt!), day);
      }).toList();
    }
    return list;
  }

  Future<void> _refreshTasks() async {
    try {
      final all = await _repository.getTasks();
      final visible = (_activePriorityFilter != null || _activeDateFilter != null)
          ? _applyFilters(all)
          : all;
      emit(
        state.copyWith(
          status: TaskListStatus.success,
          tasks: visible,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось обновить задачи: $e',
        ),
      );
    }
  }

  Future<void> loadTasks() async {
    _activePriorityFilter = null;
    _activeDateFilter = null;
    emit(state.copyWith(status: TaskListStatus.loading, errorMessage: null));
    try {
      final list = await _repository.getTasks();
      emit(
        state.copyWith(
          status: TaskListStatus.success,
          tasks: list,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось загрузить задачи: $e',
        ),
      );
    }
  }

  /// Фильтрация списка (данные берутся из репозитория, в UI попадает уже отфильтрованный список).
  Future<void> filterTasks({
    String? priority,
    DateTime? date,
  }) async {
    _activePriorityFilter = priority == 'high' ? 'high' : null;
    _activeDateFilter = date != null ? _dateOnly(date) : null;

    emit(state.copyWith(status: TaskListStatus.loading, errorMessage: null));
    try {
      final all = await _repository.getTasks();
      emit(
        state.copyWith(
          status: TaskListStatus.success,
          tasks: _applyFilters(all),
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось применить фильтр: $e',
        ),
      );
    }
  }

  Future<void> addTask(
    String title, {
    DateTime? dueAt,
    String? priority,
  }) async {
    if (title.trim().isEmpty) return;
    final task = Task(
      id: '',
      title: title.trim(),
      isCompleted: false,
      createdAt: DateTime.now(),
      dueAt: dueAt,
      priority: priority,
    );
    try {
      await _repository.addTask(task);
      await _refreshTasks();
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось добавить задачу: $e',
        ),
      );
    }
  }

  void toggleLastTask() {
    if (state.tasks.isEmpty) return;
    final id = state.tasks.last.id;
    unawaited(toggleCompleted(id));
  }

  /// Поиск задач по подстроке в заголовке.
  Future<void> searchTasks(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      await loadTasks();
      return;
    }
    emit(state.copyWith(status: TaskListStatus.loading, errorMessage: null));
    try {
      final all = await _repository.getTasks();
      final found = all.where((t) => t.title.toLowerCase().contains(q)).toList();
      emit(state.copyWith(status: TaskListStatus.success, tasks: found, errorMessage: null));
    } catch (e) {
      emit(state.copyWith(status: TaskListStatus.failure, errorMessage: 'Не удалось найти задачу: $e'));
    }
  }

  /// Удалить последнюю задачу.
  Future<void> deleteLastTask() async {
    if (state.tasks.isEmpty) return;
    final id = state.tasks.last.id;
    await deleteTask(id);
  }

  /// Найти задачу по подстроке заголовка и выполнить.
  Future<bool> findAndComplete(String titleQuery) async {
    final q = titleQuery.trim().toLowerCase();
    if (q.isEmpty) return false;
    final all = await _repository.getTasks();
    Task? best;
    for (final t in all) {
      if (!t.isCompleted && t.title.toLowerCase().contains(q)) {
        best = t;
        break;
      }
    }
    if (best == null) return false;
    await toggleCompleted(best.id);
    return true;
  }

  /// Найти задачу по подстроке заголовка и удалить.
  Future<bool> findAndDelete(String titleQuery) async {
    final q = titleQuery.trim().toLowerCase();
    if (q.isEmpty) return false;
    final all = await _repository.getTasks();
    Task? best;
    for (final t in all) {
      if (t.title.toLowerCase().contains(q)) {
        best = t;
        break;
      }
    }
    if (best == null) return false;
    await deleteTask(best.id);
    return true;
  }

  /// Удалить все выполненные задачи.
  Future<int> deleteCompleted() async {
    try {
      final all = await _repository.getTasks();
      final completed = all.where((t) => t.isCompleted).toList();
      for (final t in completed) {
        await _repository.deleteTask(t.id);
      }
      await _refreshTasks();
      return completed.length;
    } catch (e) {
      emit(state.copyWith(status: TaskListStatus.failure, errorMessage: 'Не удалось очистить задачи: $e'));
      return 0;
    }
  }

  /// Подсчёт задач (для голосовой команды).
  Future<({int total, int active, int completed})> countTasks() async {
    final all = await _repository.getTasks();
    final active = all.where((t) => !t.isCompleted).length;
    return (total: all.length, active: active, completed: all.length - active);
  }

  Future<void> toggleCompleted(String id) async {
    final all = await _repository.getTasks();
    Task? task;
    for (final t in all) {
      if (t.id == id) {
        task = t;
        break;
      }
    }
    if (task == null) return;
    try {
      await _repository.updateTask(
        task.copyWith(isCompleted: !task.isCompleted),
      );
      await _refreshTasks();
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось обновить задачу: $e',
        ),
      );
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _repository.deleteTask(id);
      await _refreshTasks();
    } catch (e) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: 'Не удалось удалить задачу: $e',
        ),
      );
    }
  }
}
