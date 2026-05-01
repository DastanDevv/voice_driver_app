import '../domain/entities/task.dart';
import '../domain/repositories/task_repository.dart';

/// Временная in-memory реализация для шага 1 (позже — Hive / Isar / drift).
class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({List<Task>? seedTasks}) {
    if (seedTasks != null) {
      _tasks.addAll(seedTasks);
      for (final t in seedTasks) {
        final n = int.tryParse(t.id.replaceFirst(RegExp(r'^task_'), ''));
        if (n != null && n > _seq) _seq = n;
      }
    }
  }

  final List<Task> _tasks = [];
  int _seq = 0;

  String _nextId() {
    _seq++;
    return 'task_$_seq';
  }

  @override
  Future<List<Task>> getTasks() async {
    return List.unmodifiable(_tasks);
  }

  @override
  Future<Task> addTask(Task task) async {
    final withId = task.id.isEmpty ? task.copyWith(id: _nextId()) : task;
    _tasks.add(withId);
    return withId;
  }

  @override
  Future<Task> updateTask(Task task) async {
    final i = _tasks.indexWhere((t) => t.id == task.id);
    if (i < 0) throw StateError('Task not found: ${task.id}');
    _tasks[i] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
}
