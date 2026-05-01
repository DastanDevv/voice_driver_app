import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command.dart';
import '../../../../core/semantic/semantic_command_runner.dart';
import '../../../../core/voice/voice_command_coordinator.dart';
import '../../../../shared/strings/app_strings.dart';
import '../../../../shared/theme/theme_cubit.dart';
import '../../../analytics/presentation/pages/analytics_page.dart';
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
      const NlpLabPage(),
      const AnalyticsPage(),
    ];

    widget.voiceCoordinator.onCommandUx = _handleCommandUx;
  }

  void _handleCommandUx(SemanticCommand cmd, String rawText) {
    if (!mounted) return;

    if (cmd.intentCode == 'navigate') {
      _handleNavigate(cmd);
      return;
    }

    if (cmd.intentCode == 'theme_toggle') {
      _handleThemeToggle(cmd);
      return;
    }

    if (cmd.intentCode == 'undo') {
      _showSnack('Функция отмены будет реализована');
      return;
    }

    if (cmd.intentCode == 'unknown') {
      _showSnack(AppStrings.unknownCommandSnack);
    } else if (cmd.confidence < 0.5) {
      _showSnack(AppStrings.lowConfidenceHint);
    }
  }

  void _handleNavigate(SemanticCommand cmd) {
    final target = cmd.entities['target'];
    switch (target) {
      case 'tasks':
        setState(() => _currentIndex = 0);
        _showSnack('Задачи');
      case 'nlp_lab':
        setState(() => _currentIndex = 1);
        _showSnack('NLP Лаборатория');
      case 'analytics':
        setState(() => _currentIndex = 2);
        _showSnack('Аналитика');
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

  void _handleThemeToggle(SemanticCommand cmd) {
    final theme = cmd.entities['theme'];
    final cubit = context.read<ThemeCubit>();
    if (theme == 'dark') {
      cubit.setDark();
      _showSnack('Тёмная тема включена');
    } else {
      cubit.setLight();
      _showSnack('Светлая тема включена');
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
