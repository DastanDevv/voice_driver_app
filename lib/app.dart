import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/semantic/command_executor.dart';
import 'core/semantic/semantic_command_runner.dart';
import 'core/voice/voice_command_coordinator.dart';
import 'core/voice/voice_service_impl.dart';
import 'features/chat/presentation/cubit/chat_cubit.dart';
import 'features/command_history/presentation/cubit/command_history_cubit.dart';
import 'features/home/presentation/pages/home_shell.dart';
import 'features/tasks/data/hive_task_repository.dart';
import 'features/tasks/domain/entities/task.dart';
import 'features/tasks/domain/repositories/task_repository.dart';
import 'features/tasks/presentation/cubit/task_cubit.dart';
import 'shared/strings/app_strings.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_cubit.dart';

class SmartTaskAssistantApp extends StatefulWidget {
  const SmartTaskAssistantApp({super.key});

  @override
  State<SmartTaskAssistantApp> createState() => _SmartTaskAssistantAppState();
}

class _SmartTaskAssistantAppState extends State<SmartTaskAssistantApp> {
  late final TaskRepository _repository;
  late final TaskCubit _taskCubit;
  late final CommandHistoryCubit _historyCubit;
  late final ChatCubit _chatCubit;
  late final ThemeCubit _themeCubit;
  late final SemanticCommandRunner _commandRunner;
  late final VoiceCommandCoordinator _voiceCoordinator;

  @override
  void initState() {
    super.initState();
    final hiveRepo = HiveTaskRepository();
    _bootstrapSeed(hiveRepo);
    _repository = hiveRepo;

    _taskCubit = TaskCubit(_repository);
    _historyCubit = CommandHistoryCubit();
    _chatCubit = ChatCubit();
    _themeCubit = ThemeCubit();
    _commandRunner = SemanticCommandRunner(
      executor: CommandExecutor(_taskCubit),
      onCommandResolved: (raw, cmd, tree) =>
          _historyCubit.record(raw, cmd, tree),
    );
    _voiceCoordinator = VoiceCommandCoordinator(
      voice: VoiceServiceImpl(),
      runner: _commandRunner,
    );
  }

  Future<void> _bootstrapSeed(HiveTaskRepository repo) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    await repo.seedIfEmpty([
      Task(
        id: '',
        title: 'Подготовить слайды к защите диплома',
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 1)),
        dueAt: today,
        priority: 'high',
      ),
      Task(
        id: '',
        title: 'Купить продукты',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 2)),
        priority: null,
      ),
      Task(
        id: '',
        title: 'Сходить в аптеку',
        isCompleted: false,
        createdAt: now,
        dueAt: today,
        priority: null,
      ),
      Task(
        id: '',
        title: 'Отправить отчёт научному руководителю',
        isCompleted: false,
        createdAt: now,
        dueAt: tomorrow,
        priority: 'high',
      ),
      Task(
        id: '',
        title: 'Записаться на курсы английского',
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 3)),
        dueAt: today.add(const Duration(days: 5)),
        priority: null,
      ),
    ]);
    await _taskCubit.loadTasks();
  }

  @override
  void dispose() {
    _voiceCoordinator.dispose();
    _historyCubit.close();
    _chatCubit.close();
    _taskCubit.close();
    _themeCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _taskCubit),
        BlocProvider.value(value: _historyCubit),
        BlocProvider.value(value: _chatCubit),
        BlocProvider.value(value: _themeCubit),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: AppStrings.appTitle,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            home: HomeShell(
              commandRunner: _commandRunner,
              voiceCoordinator: _voiceCoordinator,
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
