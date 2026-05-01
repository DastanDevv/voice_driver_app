import '../entities/task.dart';

/// Контракт хранилища задач (данные подменяются реализацией в data-слое).
abstract class TaskRepository {
  Future<List<Task>> getTasks();

  Future<Task> addTask(Task task);

  Future<Task> updateTask(Task task);

  Future<void> deleteTask(String id);
}
