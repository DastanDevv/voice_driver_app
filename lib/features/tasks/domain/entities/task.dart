import 'package:equatable/equatable.dart';

/// Доменная сущность задачи.
class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    this.dueAt,
    this.priority,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueAt;

  /// Упрощённо: `null` — обычная, `"high"` — важная (как в семантических сущностях).
  final String? priority;

  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? dueAt,
    String? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      priority: priority ?? this.priority,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        isCompleted,
        createdAt,
        dueAt,
        priority,
      ];
}
