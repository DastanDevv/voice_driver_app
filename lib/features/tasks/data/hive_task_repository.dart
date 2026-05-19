import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_storage.dart';
import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';

/// Постоянное хранилище задач через Hive (community-edition).
///
/// Задачи сериализуются в `Map<String, dynamic>` — без codegen.
class HiveTaskRepository implements TaskRepository {
  HiveTaskRepository({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Box<Map<dynamic, dynamic>> get _box => HiveStorage.tasksBox();

  Map<String, dynamic> _serialize(Task t) => {
        'id': t.id,
        'title': t.title,
        'isCompleted': t.isCompleted,
        'createdAt': t.createdAt.toIso8601String(),
        'dueAt': t.dueAt?.toIso8601String(),
        'priority': t.priority,
      };

  Task _deserialize(Map<dynamic, dynamic> m) {
    return Task(
      id: m['id'] as String,
      title: m['title'] as String,
      isCompleted: (m['isCompleted'] as bool?) ?? false,
      createdAt: DateTime.parse(m['createdAt'] as String),
      dueAt: m['dueAt'] != null ? DateTime.parse(m['dueAt'] as String) : null,
      priority: m['priority'] as String?,
    );
  }

  @override
  Future<List<Task>> getTasks() async {
    return _box.values.map(_deserialize).toList();
  }

  @override
  Future<Task> addTask(Task task) async {
    final withId =
        task.id.isEmpty ? task.copyWith(id: _uuid.v4()) : task;
    await _box.put(withId.id, _serialize(withId));
    return withId;
  }

  @override
  Future<Task> updateTask(Task task) async {
    if (!_box.containsKey(task.id)) {
      throw StateError('Task not found: ${task.id}');
    }
    await _box.put(task.id, _serialize(task));
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  /// Засеять стартовые задачи только если хранилище пустое (первый запуск).
  Future<void> seedIfEmpty(List<Task> seedTasks) async {
    if (_box.isNotEmpty) return;
    for (final t in seedTasks) {
      final withId = t.id.isEmpty ? t.copyWith(id: _uuid.v4()) : t;
      await _box.put(withId.id, _serialize(withId));
    }
  }
}
