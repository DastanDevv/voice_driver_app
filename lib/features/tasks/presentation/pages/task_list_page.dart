import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command.dart';
import '../../../../core/semantic/semantic_command_runner.dart';
import '../../../../core/voice/voice_command_coordinator.dart';
import '../../../../shared/formatters/ru_date_format.dart';
import '../../../../shared/strings/app_strings.dart';
import '../../../command_history/presentation/cubit/command_history_cubit.dart';
import '../../../command_history/presentation/pages/command_history_page.dart';
import '../../../home/about/about_page.dart';
import '../../domain/entities/task.dart';
import '../cubit/task_cubit.dart';
import '../cubit/task_state.dart';

enum _ListSortMode { byDate, byPriority }

enum _FilterChip { all, today, important }

class TaskListPage extends StatefulWidget {
  const TaskListPage({
    super.key,
    required this.commandRunner,
    required this.voiceCoordinator,
  });

  final SemanticCommandRunner commandRunner;
  final VoiceCommandCoordinator voiceCoordinator;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage>
    with TickerProviderStateMixin {
  bool _demoRunning = false;
  bool _scriptBusy = false;
  _FilterChip _filter = _FilterChip.all;
  _ListSortMode _sortMode = _ListSortMode.byDate;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    context.read<TaskCubit>().loadTasks();
    widget.voiceCoordinator.listening.addListener(_onListeningChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.voiceCoordinator.attachMicUnavailable(() {
        if (!mounted) return;
        _showAppSnackBar(AppStrings.micUnavailable);
      });
    });
  }

  void _onListeningChanged() {
    final listening = widget.voiceCoordinator.listening.value;
    if (listening) {
      if (!_pulseController.isAnimating) {
        unawaited(_pulseController.repeat(reverse: true));
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.voiceCoordinator.listening.removeListener(_onListeningChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _showAppSnackBar(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        content: Text(message),
      ),
    );
  }

  void _applyCommandUx(BuildContext context, SemanticCommand cmd, String raw) {
    if (!context.mounted) return;
    if (cmd.intentCode == 'unknown') {
      _showAppSnackBar(AppStrings.unknownCommandSnack);
    } else if (cmd.confidence < 0.5) {
      _showAppSnackBar(AppStrings.lowConfidenceHint);
    }
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => BlocProvider.value(
          value: context.read<CommandHistoryCubit>(),
          child: const CommandHistoryPage(),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _runDemoScript() async {
    if (_demoRunning) return;
    setState(() => _demoRunning = true);
    try {
      for (final phrase in SemanticCommandRunner.demoPhrases) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        setState(() => _scriptBusy = true);
        try {
          final (cmd, _) = await widget.commandRunner.run(phrase);
          _applyCommandUx(context, cmd, phrase);
        } finally {
          if (mounted) setState(() => _scriptBusy = false);
        }
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    } finally {
      if (mounted) setState(() => _demoRunning = false);
    }
  }

  Future<void> _applyFilter(_FilterChip chip) async {
    setState(() => _filter = chip);
    final cubit = context.read<TaskCubit>();
    switch (chip) {
      case _FilterChip.all:
        await cubit.loadTasks();
      case _FilterChip.today:
        await cubit.filterTasks(date: DateTime.now());
      case _FilterChip.important:
        await cubit.filterTasks(priority: 'high');
    }
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _AddTaskDialogSheet(),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      await context.read<TaskCubit>().addTask(result.trim());
    }
  }

  List<Task> _sorted(List<Task> tasks) {
    final copy = List<Task>.from(tasks);
    int cmp(Task a, Task b) {
      switch (_sortMode) {
        case _ListSortMode.byPriority:
          final ah = a.priority == 'high' ? 0 : 1;
          final bh = b.priority == 'high' ? 0 : 1;
          if (ah != bh) return ah.compareTo(bh);
          final ad = a.dueAt;
          final bd = b.dueAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        case _ListSortMode.byDate:
          final ad = a.dueAt;
          final bd = b.dueAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
      }
    }

    copy.sort(cmp);
    return copy;
  }

  Map<_DueSection, List<Task>> _groupByDue(List<Task> tasks, DateTime now) {
    final today = dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final groups = <_DueSection, List<Task>>{
      _DueSection.today: [],
      _DueSection.tomorrow: [],
      _DueSection.later: [],
    };
    for (final t in tasks) {
      final d = t.dueAt;
      if (d == null) {
        groups[_DueSection.later]!.add(t);
        continue;
      }
      final day = dateOnly(d);
      if (day == today) {
        groups[_DueSection.today]!.add(t);
      } else if (day == tomorrow) {
        groups[_DueSection.tomorrow]!.add(t);
      } else {
        groups[_DueSection.later]!.add(t);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final listening = widget.voiceCoordinator.listening.value;
    final voiceProcessing = widget.voiceCoordinator.processing.value;
    final processing = voiceProcessing || _scriptBusy;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.taskListTitle),
        actions: [
          PopupMenuButton<_ListSortMode>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: AppStrings.sortByDate,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _ListSortMode.byDate,
                checked: _sortMode == _ListSortMode.byDate,
                child: const Text(AppStrings.sortByDate),
              ),
              CheckedPopupMenuItem(
                value: _ListSortMode.byPriority,
                checked: _sortMode == _ListSortMode.byPriority,
                child: const Text(AppStrings.sortByPriority),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: AppStrings.historyTooltip,
            onPressed: _openHistory,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: AppStrings.moreMenu,
            onSelected: (value) {
              if (value == 'demo') {
                unawaited(_runDemoScript());
              } else if (value == 'test') {
                unawaited(() async {
                  final (cmd, _) = await widget.commandRunner
                      .run(SemanticCommandRunner.demoPhrase);
                  if (!context.mounted) return;
                  _applyCommandUx(
                    context,
                    cmd,
                    SemanticCommandRunner.demoPhrase,
                  );
                }());
              } else if (value == 'about') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: context.read<TaskCubit>(),
                      child: const AboutPage(),
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'demo',
                enabled: !_demoRunning,
                child: Text(AppStrings.demoCommandsButton),
              ),
              const PopupMenuItem(
                value: 'test',
                child: Text(AppStrings.testCommandButton),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Text(AppStrings.aboutTitle),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          BlocBuilder<TaskCubit, TaskState>(
            builder: (context, state) {
              if (state.status == TaskListStatus.loading &&
                  state.tasks.isEmpty) {
                return const Center(child: Text(AppStrings.loadingTasks));
              }

              final showEmpty = state.tasks.isEmpty;
              final active = showEmpty
                  ? <Task>[]
                  : _sorted(
                      state.tasks.where((t) => !t.isCompleted).toList(),
                    );
              final done = showEmpty
                  ? <Task>[]
                  : _sorted(state.tasks.where((t) => t.isCompleted).toList());

              final total = active.length + done.length;
              final progress = total > 0 ? done.length / total : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (total > 0)
                    _TaskProgressBar(
                      progress: progress,
                      doneCount: done.length,
                      totalCount: total,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _FilterChipsRow(
                      selected: _filter,
                      onSelected: (f) => unawaited(_applyFilter(f)),
                    ),
                  ),
                  Expanded(
                    child: showEmpty
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: const _EmptyTasksState(
                              key: ValueKey('empty'),
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: ListView(
                              key: ValueKey(
                                '${state.tasks.length}_$_filter$_sortMode',
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 160),
                              children: [
                                if (state.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: MaterialBanner(
                                      content: Text(state.errorMessage!),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            setState(
                                              () => _filter = _FilterChip.all,
                                            );
                                            context
                                                .read<TaskCubit>()
                                                .loadTasks();
                                          },
                                          child: const Text('Повторить'),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (active.isNotEmpty) ...[
                                  if (_filter == _FilterChip.all) ...[
                                    ..._buildGroupedActive(context, active),
                                  ] else ...[
                                    _SectionHeader(title: AppStrings.activeLabel),
                                    ...active.map((t) => _TaskCard(task: t)),
                                  ],
                                ],
                                if (done.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _SectionHeader(
                                    title: AppStrings.completedLabel,
                                  ),
                                  ...done.map((t) => _TaskCard(task: t)),
                                ],
                              ],
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
          if (processing && !listening)
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: _StatusBanner(
                label: AppStrings.processingLabel,
                icon: Icons.hourglass_top_rounded,
                color: scheme.secondaryContainer,
                onColor: scheme.onSecondaryContainer,
              ),
            ),
          if (listening)
            _ListeningOverlay(
              partialTranscript: widget.voiceCoordinator.partialTranscript,
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_task',
            onPressed: _showAddDialog,
            tooltip: AppStrings.addTaskTooltip,
            child: const Icon(Icons.add_rounded),
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: AppStrings.voiceHoldHint,
            child: Semantics(
              button: true,
              label: AppStrings.voiceHoldHint,
              child: _VoiceFab(
                listening: listening,
                pulse: _pulseController,
                onDown: () =>
                    unawaited(widget.voiceCoordinator.handlePointerDown()),
                onUp: () =>
                    unawaited(widget.voiceCoordinator.handlePointerUp()),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<Widget> _buildGroupedActive(BuildContext context, List<Task> active) {
    final now = DateTime.now();
    final groups = _groupByDue(active, now);
    final out = <Widget>[];
    void addSection(String title, List<Task> items) {
      if (items.isEmpty) return;
      out.add(_SectionHeader(title: title));
      out.addAll(items.map((t) => _TaskCard(task: t)));
    }

    addSection(AppStrings.sectionToday, groups[_DueSection.today]!);
    addSection(AppStrings.sectionTomorrow, groups[_DueSection.tomorrow]!);
    addSection(AppStrings.sectionLater, groups[_DueSection.later]!);
    if (out.isEmpty) {
      out.add(_SectionHeader(title: AppStrings.activeLabel));
      out.addAll(active.map((t) => _TaskCard(task: t)));
    }
    return out;
  }
}

enum _DueSection { today, tomorrow, later }

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({super.key});

  static const _suggestions = [
    'Создай задачу купить хлеб на завтра',
    'Покажи важные задачи',
    'Сколько задач?',
    'Найди задачу презентацию',
    'Помощь',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.mic_none_rounded,
                  size: 52,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.emptyListTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.emptyListSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Text(
              AppStrings.voiceSuggestionsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskProgressBar extends StatelessWidget {
  const _TaskProgressBar({
    required this.progress,
    required this.doneCount,
    required this.totalCount,
  });

  final double progress;
  final int doneCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final pct = (progress * 100).round();
    final color = pct == 100
        ? const Color(0xFF16A34A)
        : scheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$doneCount/$totalCount',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.selected,
    required this.onSelected,
  });

  final _FilterChip selected;
  final ValueChanged<_FilterChip> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(_FilterChip value, String label) {
      final isSel = selected == value;
      return FilterChip(
        label: Text(label),
        selected: isSel,
        showCheckmark: false,
        onSelected: (_) => onSelected(value),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_FilterChip.all, AppStrings.filterAll),
          const SizedBox(width: 8),
          chip(_FilterChip.today, AppStrings.filterToday),
          const SizedBox(width: 8),
          chip(_FilterChip.important, AppStrings.filterImportant),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.label,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(16),
      color: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: onColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningOverlay extends StatelessWidget {
  const _ListeningOverlay({required this.partialTranscript});

  final ValueNotifier<String> partialTranscript;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.scrim.withValues(alpha: 0.35),
          ),
          child: Center(
            child: Material(
              elevation: 8,
              shadowColor: scheme.shadow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              color: scheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.listening,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 20),
                    const _WaveformBars(),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<String>(
                      valueListenable: partialTranscript,
                      builder: (context, text, _) {
                        if (text.isEmpty) return const SizedBox.shrink();
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformBars extends StatefulWidget {
  const _WaveformBars();

  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final phase = _c.value * 2 * math.pi + i * 0.55;
              final h = 10 + 22 * (0.5 + 0.5 * math.sin(phase));
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: 5,
                  height: h.clamp(8.0, 36.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: scheme.primary.withValues(alpha: 0.75),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _VoiceFab extends StatelessWidget {
  const _VoiceFab({
    required this.listening,
    required this.pulse,
    required this.onDown,
    required this.onUp,
  });

  final bool listening;
  final AnimationController pulse;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = listening ? pulse.value : 0.0;
          final scale = 1.0 + 0.08 * t;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(
                  alpha: listening ? 0.55 : 0.28,
                ),
                blurRadius: listening ? 28 : 14,
                spreadRadius: listening ? 4 : 0,
              ),
            ],
          ),
          child: Icon(
            Icons.mic_rounded,
            size: 34,
            color: scheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final high = task.priority == 'high';
    final cardColor = high
        ? scheme.errorContainer.withValues(alpha: 0.35)
        : scheme.surface;
    final borderColor = high
        ? scheme.error.withValues(alpha: 0.35)
        : scheme.outlineVariant.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('task_${task.id}'),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            task.isCompleted
                ? Icons.replay_rounded
                : Icons.check_rounded,
            color: scheme.onTertiaryContainer,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: scheme.onErrorContainer,
            size: 28,
          ),
        ),
        confirmDismiss: (direction) async {
          final cubit = context.read<TaskCubit>();
          if (direction == DismissDirection.startToEnd) {
            await cubit.toggleCompleted(task.id);
            return false;
          }
          await cubit.deleteTask(task.id);
          return true;
        },
        child: Material(
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          color: cardColor,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showTaskDetail(context, task),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Checkbox.adaptive(
                        value: task.isCompleted,
                        onChanged: (_) => context
                            .read<TaskCubit>()
                            .toggleCompleted(task.id),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (task.dueAt != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_rounded,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatRuShortDayMonth(task.dueAt!),
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              if (high)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    AppStrings.highPriorityLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.deleteTooltip,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () =>
                          context.read<TaskCubit>().deleteTask(task.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showTaskDetail(BuildContext context, Task task) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final high = task.priority == 'high';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(ctx).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: high
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    task.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: high
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    task.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (high)
                  _DetailChip(
                    icon: Icons.priority_high_rounded,
                    label: AppStrings.highPriorityLabel,
                    color: scheme.error,
                    bgColor: scheme.errorContainer.withValues(alpha: 0.4),
                  ),
                if (task.dueAt != null)
                  _DetailChip(
                    icon: Icons.event_rounded,
                    label: formatRuShortDayMonth(task.dueAt!),
                    color: scheme.primary,
                    bgColor: scheme.primaryContainer.withValues(alpha: 0.5),
                  ),
                _DetailChip(
                  icon: Icons.access_time_rounded,
                  label: '${task.createdAt.day}.${task.createdAt.month.toString().padLeft(2, "0")}.${task.createdAt.year}',
                  color: scheme.onSurfaceVariant,
                  bgColor: scheme.surfaceContainerHighest,
                ),
                _DetailChip(
                  icon: task.isCompleted
                      ? Icons.check_circle_outline_rounded
                      : Icons.circle_outlined,
                  label:
                      task.isCompleted ? AppStrings.completedLabel : AppStrings.activeLabel,
                  color: task.isCompleted
                      ? const Color(0xFF16A34A)
                      : scheme.primary,
                  bgColor: task.isCompleted
                      ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                      : scheme.primaryContainer.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<TaskCubit>().toggleCompleted(task.id);
                    },
                    icon: Icon(
                      task.isCompleted
                          ? Icons.replay_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      task.isCompleted ? 'Вернуть' : 'Выполнить',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<TaskCubit>().deleteTask(task.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text(AppStrings.deleteTooltip),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Контроллер живёт в [State.dispose] — не освобождаем до полного снятия маршрута диалога.
class _AddTaskDialogSheet extends StatefulWidget {
  const _AddTaskDialogSheet();

  @override
  State<_AddTaskDialogSheet> createState() => _AddTaskDialogSheetState();
}

class _AddTaskDialogSheetState extends State<_AddTaskDialogSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addTaskDialogTitle),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: AppStrings.addTaskHint,
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}
