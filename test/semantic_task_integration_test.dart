import 'package:flutter_test/flutter_test.dart';
import 'package:voice_driver_mobile/core/nlp/russian_nlp_engine.dart';
import 'package:voice_driver_mobile/core/semantic/command_executor.dart';
import 'package:voice_driver_mobile/features/tasks/data/task_repository_impl.dart';
import 'package:voice_driver_mobile/features/tasks/domain/entities/task.dart';
import 'package:voice_driver_mobile/features/tasks/presentation/cubit/task_cubit.dart';

void main() {
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  test('1. создай задачу купить молоко завтра → due завтра', () async {
    final repo = InMemoryTaskRepository();
    final cubit = TaskCubit(repo);
    await CommandExecutor(cubit).execute(
      RussianNlpEngine().parse('создай задачу купить молоко завтра'),
    );
    await settle();
    final tasks = await repo.getTasks();
    expect(tasks, hasLength(1));
    final due = tasks.single.dueAt!;
    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    expect(dateOnly(due), tomorrow);
  });

  test('2. создай задачу позвонить через 2 часа → due ~+2ч', () async {
    final repo = InMemoryTaskRepository();
    final cubit = TaskCubit(repo);
    final before = DateTime.now();
    await CommandExecutor(cubit).execute(
      RussianNlpEngine().parse('создай задачу позвонить через 2 часа'),
    );
    await settle();
    final due = (await repo.getTasks()).single.dueAt!;
    final diff = due.difference(before);
    expect(diff.inHours, inInclusiveRange(1, 3));
  });

  test('3. покажи важные задачи → только high', () async {
    final repo = InMemoryTaskRepository(
      seedTasks: [
        Task(
          id: 'h',
          title: 'Важное',
          isCompleted: false,
          createdAt: DateTime.now(),
          priority: 'high',
        ),
        Task(
          id: 'n',
          title: 'Обычное',
          isCompleted: false,
          createdAt: DateTime.now(),
          priority: null,
        ),
      ],
    );
    final cubit = TaskCubit(repo);
    await cubit.loadTasks();
    await CommandExecutor(cubit).execute(
      RussianNlpEngine().parse('покажи важные задачи'),
    );
    await settle();
    expect(cubit.state.tasks, hasLength(1));
    expect(cubit.state.tasks.single.title, 'Важное');
  });

  test('4. покажи задачи на сегодня → только с тем же календарным днём', () async {
    final start = dateOnly(DateTime.now());
    final repo = InMemoryTaskRepository(
      seedTasks: [
        Task(
          id: 't1',
          title: 'Сегодня',
          isCompleted: false,
          createdAt: DateTime.now(),
          dueAt: start,
        ),
        Task(
          id: 't2',
          title: 'Без срока',
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      ],
    );
    final cubit = TaskCubit(repo);
    await cubit.loadTasks();
    await CommandExecutor(cubit).execute(
      RussianNlpEngine().parse('покажи задачи на сегодня'),
    );
    await settle();
    expect(cubit.state.tasks, hasLength(1));
    expect(cubit.state.tasks.single.title, 'Сегодня');
  });
}
