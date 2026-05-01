import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/strings/app_strings.dart';
import '../../../shared/theme/theme_cubit.dart';

/// Экран «О системе» — архитектура, тема диплома, описание пайплайна.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
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
          _SectionCard(
            title: 'Архитектура Voice-Driven UI',
            icon: Icons.architecture_rounded,
            color: Colors.indigo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PipelineStep(
                  number: '1',
                  title: 'Speech-to-Text (STT)',
                  description: 'Распознавание русской речи через Google Speech API',
                  icon: Icons.mic_rounded,
                  color: Colors.blue,
                ),
                _PipelineStep(
                  number: '2',
                  title: 'NLP Parser (RussianNlpEngine)',
                  description: 'Локальный семантический разбор: нормализация, извлечение сущностей, определение намерения',
                  icon: Icons.psychology_rounded,
                  color: Colors.purple,
                ),
                _PipelineStep(
                  number: '3',
                  title: 'Context Manager',
                  description: 'Диалоговый контекст: объединение уточнений с предыдущей командой',
                  icon: Icons.merge_type_rounded,
                  color: Colors.orange,
                ),
                _PipelineStep(
                  number: '4',
                  title: 'Command Executor',
                  description: 'Маппинг семантических команд на действия в TaskCubit',
                  icon: Icons.play_circle_rounded,
                  color: Colors.green,
                ),
                _PipelineStep(
                  number: '5',
                  title: 'Text-to-Speech (TTS)',
                  description: 'Голосовой ответ пользователю на русском языке',
                  icon: Icons.volume_up_rounded,
                  color: Colors.teal,
                  isLast: true,
                ),
              ],
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

  static const _intents = <String, String>{
    'create_task': '«Создай задачу купить хлеб на завтра»',
    'show_tasks': '«Покажи важные задачи»',
    'complete_task': '«Выполни задачу купить хлеб»',
    'delete_task': '«Удали задачу презентацию»',
    'search_task': '«Найди задачу хлеб»',
    'count_tasks': '«Сколько задач?»',
    'clear_completed': '«Очисти выполненные»',
    'help': '«Помощь» / «Что ты умеешь?»',
    'navigate': '«Открой аналитику» / «Перейди в лабораторию»',
    'theme_toggle': '«Включи тёмную тему»',
    'undo': '«Отмена»',
  };

  static const _techStack = [
    'Flutter 3.x',
    'Dart 3.x',
    'Material 3',
    'BLoC / Cubit',
    'Clean Architecture',
    'speech_to_text',
    'flutter_tts',
    'Semantic NLP',
    'Context Manager',
  ];
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: 56,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Smart Task Assistant',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Разработка мобильного приложения архитектуры\n'
              'голосового управления интерфейсом (Voice-Driven UI)\n'
              'на основе анализа семантического дерева',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
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
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
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
