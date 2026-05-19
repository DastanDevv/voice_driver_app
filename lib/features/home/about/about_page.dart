import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/voice/voice_command_coordinator.dart';
import '../../../shared/strings/app_strings.dart';
import '../../../shared/theme/theme_cubit.dart';
import '../../architecture/presentation/pages/architecture_page.dart';

/// Экран «О системе» — архитектура, тема диплома, описание пайплайна.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.voiceCoordinator});

  final VoiceCommandCoordinator? voiceCoordinator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.aboutTitle),
        actions: [
          IconButton(
            icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
            onPressed: () => context.read<ThemeCubit>().toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeaderCard(scheme: scheme),
          const SizedBox(height: 16),
          if (voiceCoordinator != null)
            _ActionCard(
              title: 'Живой граф архитектуры',
              subtitle: 'Подсветка узлов пайплайна в реальном времени',
              icon: Icons.bolt_rounded,
              color: scheme.tertiary,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ArchitecturePage(
                      voiceCoordinator: voiceCoordinator!,
                    ),
                  ),
                );
              },
            ),
          if (voiceCoordinator != null) const SizedBox(height: 16),
          _SectionCard(
            title: 'Архитектура Voice-Driven UI',
            icon: Icons.architecture_rounded,
            color: Colors.indigo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _pipelineSteps,
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Голосовые команды (${_intents.length})',
            icon: Icons.record_voice_over_rounded,
            color: Colors.blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _intents.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          e.key,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Ключевые научные элементы',
            icon: Icons.school_rounded,
            color: Colors.deepPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _scienceItems
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Технологический стек',
            icon: Icons.layers_rounded,
            color: Colors.teal,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _techStack.map((tech) {
                return Chip(
                  label: Text(tech),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> get _pipelineSteps => const [
        _PipelineStep(
          number: '1',
          title: 'Speech-to-Text (STT)',
          description: 'Распознавание русской речи через speech_to_text',
          icon: Icons.mic_rounded,
          color: Color(0xFF60A5FA),
        ),
        _PipelineStep(
          number: '2',
          title: 'Command Splitter',
          description:
              'Разбиение составных запросов по конъюнкциям («и потом», «а также»)',
          icon: Icons.call_split_rounded,
          color: Color(0xFFA78BFA),
        ),
        _PipelineStep(
          number: '3',
          title: 'NLP Parser (RussianNlpEngine)',
          description:
              'Локальный семантический разбор: нормализация, извлечение сущностей',
          icon: Icons.psychology_rounded,
          color: Color(0xFFE879F9),
        ),
        _PipelineStep(
          number: '4',
          title: 'Context Manager',
          description:
              'Диалоговый контекст: объединение уточнений с предыдущей командой',
          icon: Icons.merge_type_rounded,
          color: Color(0xFFFB923C),
        ),
        _PipelineStep(
          number: '5',
          title: 'Semantic Tree Builder',
          description:
              'Построение иерархического семантического дерева ROOT → ACTION → OBJECT → MODIFIERS',
          icon: Icons.account_tree_rounded,
          color: Color(0xFFFBBF24),
        ),
        _PipelineStep(
          number: '6',
          title: 'Command Executor',
          description:
              'Маппинг семантической структуры на бизнес-действия (TaskCubit)',
          icon: Icons.play_circle_rounded,
          color: Color(0xFF34D399),
        ),
        _PipelineStep(
          number: '7',
          title: 'Text-to-Speech (TTS)',
          description: 'Голосовой ответ пользователю на русском языке',
          icon: Icons.volume_up_rounded,
          color: Color(0xFF22D3EE),
          isLast: true,
        ),
      ];

  static const _intents = <String, String>{
    'create_task': '«Создай задачу купить хлеб на завтра»',
    'show_tasks': '«Покажи важные задачи»',
    'complete_task': '«Выполни задачу купить хлеб»',
    'delete_task': '«Удали задачу презентацию»',
    'search_task': '«Найди задачу хлеб»',
    'count_tasks': '«Сколько задач?»',
    'clear_completed': '«Очисти выполненные»',
    'help': '«Помощь» / «Что ты умеешь?»',
    'navigate':
        '«Открой аналитику» / «Перейди в чат» / «Покажи архитектуру»',
    'theme_toggle': '«Включи тёмную тему»',
    'undo': '«Отмена»',
    'wake_word': '«Привет, ассистент, покажи задачи»',
    'multi': '«Создай задачу X а потом удали Y»',
  };

  static const _scienceItems = [
    'Иерархическое семантическое дерево как формальное представление команды (тема диплома)',
    'Обработка диалогового контекста: фрагментарные уточнения склеиваются с предыдущим намерением',
    'Многоступенчатый пайплайн: STT → Splitter → NLP → Context → Tree → Executor → TTS',
    'Поддержка составных запросов через разбиение по русским конъюнкциям',
    'Wake-word активация: «Привет, ассистент» — управление без рук',
    'Локальная персистентность через Hive — приложение работает без сети',
  ];

  static const _techStack = [
    'Flutter 3.x',
    'Dart 3.x',
    'Material 3',
    'BLoC / Cubit',
    'Clean Architecture',
    'speech_to_text',
    'flutter_tts',
    'graphview',
    'hive_ce',
    'uuid',
    'Semantic Tree',
    'Context Manager',
  ];
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.record_voice_over_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Task Assistant',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Разработка мобильного приложения архитектуры '
              'голосового управления интерфейсом (Voice-Driven UI) '
              'на основе анализа семантического дерева',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 1,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  number,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
