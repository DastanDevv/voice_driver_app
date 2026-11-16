import 'dart:ui';

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

/// Корневой shell с floating Bottom Navigation + голосовая навигация.
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
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

// ── Floating pill bottom navigation ────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (
      icon: Icons.task_alt_outlined,
      activeIcon: Icons.task_alt_rounded,
      label: 'Задачи',
    ),
    (
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'Чат',
    ),
    (
      icon: Icons.science_outlined,
      activeIcon: Icons.science_rounded,
      label: 'NLP Lab',
    ),
    (
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
      label: 'Аналит.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1C35).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? scheme.outlineVariant.withValues(alpha: 0.2)
                    : scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                _items.length,
                (index) => _NavPill(
                  icon: _items[index].icon,
                  activeIcon: _items[index].activeIcon,
                  label: _items[index].label,
                  isSelected: index == selectedIndex,
                  onTap: () => onTap(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    scheme.primary,
                    Color.lerp(scheme.primary, scheme.tertiary, 0.55)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                size: 22,
                color: isSelected
                    ? Colors.white
                    : scheme.onSurfaceVariant,
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
