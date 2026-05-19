import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command_runner.dart';
import '../../../../core/voice/voice_command_coordinator.dart';
import '../../../../shared/strings/app_strings.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../architecture/presentation/pages/architecture_page.dart';
import '../../../chat/presentation/cubit/chat_cubit.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../command_history/presentation/cubit/command_history_cubit.dart';
import '../../../command_history/presentation/pages/command_history_page.dart';
import '../../../nlp_lab/presentation/pages/nlp_lab_page.dart';
import '../../../tasks/presentation/pages/task_list_page.dart';

/// Корневой shell с Bottom Navigation + голосовая навигация.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.commandRunner,
    required this.voiceCoordinator,
  });

  final SemanticCommandRunner commandRunner;
  final VoiceCommandCoordinator voiceCoordinator;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TaskListPage(
        commandRunner: widget.commandRunner,
        voiceCoordinator: widget.voiceCoordinator,
      ),
      ChatPage(
        commandRunner: widget.commandRunner,
        voiceCoordinator: widget.voiceCoordinator,
      ),
      NlpLabPage(voiceCoordinator: widget.voiceCoordinator),
      const AnalyticsPage(),
    ];

    widget.voiceCoordinator.onCommandsExecuted = _handleCommandsExecuted;
  }

  void _handleCommandsExecuted(List<RunOutcome> outcomes, String rawText) {
    if (!mounted || outcomes.isEmpty) return;

    final chat = context.read<ChatCubit>();
    chat.appendUserMessage(rawText);

    for (final outcome in outcomes) {
      _applySideEffects(outcome);
      final assistantText = outcome.execution.message ?? _phraseFor(outcome);
      chat.appendAssistantMessage(assistantText, command: outcome.command);
    }

    final last = outcomes.last;
    if (last.command.intentCode == 'unknown') {
      _showSnack(AppStrings.unknownCommandSnack);
    } else if (last.command.confidence < 0.5) {
      _showSnack(AppStrings.lowConfidenceHint);
    }
  }

  String _phraseFor(RunOutcome outcome) {
    switch (outcome.command.intentCode) {
      case 'create_task':
        return 'Задача добавлена';
      case 'show_tasks':
        return 'Показаны задачи';
      case 'complete_task':
        return 'Задача отмечена выполненной';
      case 'delete_task':
        return 'Задача удалена';
      case 'search_task':
        return 'Результаты поиска показаны';
      case 'navigate':
        return 'Переключаю экран';
      case 'theme_toggle':
        return 'Тема изменена';
      case 'undo':
        return 'Действие отменено';
      case 'help':
        return 'Я умею создавать, показывать, выполнять, удалять, искать, считать задачи, менять тему и навигацию.';
      default:
        return 'Не удалось распознать команду';
    }
  }

  void _applySideEffects(RunOutcome outcome) {
    final cmd = outcome.command;
    if (cmd.intentCode == 'navigate') {
      _handleNavigate(cmd.entities['target']);
    } else if (cmd.intentCode == 'theme_toggle') {
      _handleThemeToggle(cmd.entities['theme']);
    }
  }

  void _handleNavigate(Object? target) {
    switch (target) {
      case 'tasks':
        setState(() => _currentIndex = 0);
      case 'chat':
        setState(() => _currentIndex = 1);
      case 'nlp_lab':
        setState(() => _currentIndex = 2);
      case 'analytics':
        setState(() => _currentIndex = 3);
      case 'architecture':
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ArchitecturePage(
              voiceCoordinator: widget.voiceCoordinator,
            ),
          ),
        );
      case 'history':
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: context.read<CommandHistoryCubit>(),
              child: const CommandHistoryPage(),
            ),
          ),
        );
    }
  }

  void _handleThemeToggle(Object? theme) {
    final cubit = context.read<ThemeCubit>();
    if (theme == 'dark') {
      cubit.setDark();
    } else {
      cubit.setLight();
    }
  }

  void _showSnack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: AppStrings.navTasks,
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Чат',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: AppStrings.navNlpLab,
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: AppStrings.navAnalytics,
          ),
        ],
      ),
    );
  }
}
