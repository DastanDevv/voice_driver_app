import 'package:equatable/equatable.dart';

import '../../domain/entities/task.dart';

enum TaskListStatus {
  initial,
  loading,
  success,
  failure,
}

class _UnsetErrorMessage {
  const _UnsetErrorMessage();
}

const _unsetErrorMessage = _UnsetErrorMessage();

class TaskState extends Equatable {
  const TaskState({
    this.status = TaskListStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  final TaskListStatus status;
  final List<Task> tasks;

  /// Сообщение об ошибке на русском для отображения в UI.
  final String? errorMessage;

  TaskState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    Object? errorMessage = _unsetErrorMessage,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: identical(errorMessage, _unsetErrorMessage)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [status, tasks, errorMessage];
}
