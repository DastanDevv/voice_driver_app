import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/nlp/russian_nlp_engine.dart';
import '../../../../core/semantic/context_manager.dart';
import '../../../../core/semantic/semantic_command.dart';
import '../../../../shared/strings/app_strings.dart';

/// Визуализация NLP-пайплайна: текст → нормализация → разбор → контекст → результат.
/// Ключевой экран для демонстрации темы дипломной работы.
class NlpLabPage extends StatefulWidget {
  const NlpLabPage({super.key});

  @override
  State<NlpLabPage> createState() => _NlpLabPageState();
}

class _NlpLabPageState extends State<NlpLabPage> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _engine = RussianNlpEngine();
  final _contextManager = ContextManager();

  _PipelineResult? _result;
  int _visibleSteps = 0;
  Timer? _stepTimer;

  static const _samplePhrases = [
    'Создай задачу купить хлеб на завтра',
    'Покажи важные задачи',
    'Добавь срочную задачу подготовить презентацию',
    'Выполни задачу купить хлеб',
    'Покажи задачи на сегодня',
    'Создай задачу позвонить маме через два часа',
    'Удали задачу купить хлеб',
    'Найди задачу презентацию',
    'Сколько задач',
    'Очисти выполненные',
    'Помощь',
    'Открой аналитику',
    'Перейди в лабораторию',
    'Включи тёмную тему',
    'Включи светлую тему',
    'Отмена',
    'Только важные',
    'На завтра',
  ];

  @override
  void dispose() {
    _stepTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _analyze(String text) {
    if (text.trim().isEmpty) return;

    _stepTimer?.cancel();

    final raw = text.trim();
    final normalized = _engine.normalize(raw);
    final parsed = _engine.parse(raw);
    final dateEntities = _engine.extractDate(normalized);
    final priorityEntities = <String, dynamic>{};
    _engine.extractPriority(normalized, priorityEntities);
    final resolved = _contextManager.applyContext(parsed);

    setState(() {
      _result = _PipelineResult(
        raw: raw,
        normalized: normalized,
        dateEntities: dateEntities,
        priorityEntities: priorityEntities,
        parsed: parsed,
        resolved: resolved,
        contextUsed: resolved.intentCode != parsed.intentCode ||
            resolved.entities.length != parsed.entities.length,
      );
      _visibleSteps = 0;
    });

    _stepTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _visibleSteps++);
      if (_visibleSteps >= 6) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text(AppStrings.nlpLabTitle),
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: AppStrings.nlpLabHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () => _analyze(_controller.text),
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _analyze,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.nlpLabSamples,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _samplePhrases.map((phrase) {
                      return ActionChip(
                        label: Text(
                          phrase,
                          style: theme.textTheme.labelMedium,
                        ),
                        onPressed: () {
                          _controller.text = phrase;
                          _analyze(phrase);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          if (_result != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  _buildSteps(context, _result!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(BuildContext context, _PipelineResult r) {
    final steps = <Widget>[];

    if (_visibleSteps >= 1) {
      steps.add(_PipelineStepCard(
        index: 1,
        title: 'Входной текст',
        icon: Icons.text_fields_rounded,
        color: Colors.blueGrey,
        child: _CodeBlock(text: '"${r.raw}"'),
      ));
    }

    if (_visibleSteps >= 2) {
      steps.add(_PipelineStepCard(
        index: 2,
        title: 'Нормализация',
        subtitle: 'lowercase, ё→е, trim, collapse spaces',
        icon: Icons.cleaning_services_rounded,
        color: Colors.teal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CodeBlock(text: '"${r.normalized}"'),
            if (r.raw.toLowerCase() != r.normalized)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _DiffBadge(
                  label: 'Изменено',
                  color: Colors.teal,
                ),
              ),
          ],
        ),
      ));
    }

    if (_visibleSteps >= 3) {
      steps.add(_PipelineStepCard(
        index: 3,
        title: 'Извлечение сущностей',
        subtitle: 'дата, время, приоритет',
        icon: Icons.account_tree_rounded,
        color: Colors.deepPurple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.dateEntities.isNotEmpty)
              ...r.dateEntities.entries.map(
                (e) => _EntityRow(name: e.key, value: '${e.value}'),
              ),
            if (r.priorityEntities.isNotEmpty)
              ...r.priorityEntities.entries.map(
                (e) => _EntityRow(name: e.key, value: '${e.value}'),
              ),
            if (r.dateEntities.isEmpty && r.priorityEntities.isEmpty)
              Text(
                'Нет дополнительных сущностей',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ));
    }

    if (_visibleSteps >= 4) {
      steps.add(_PipelineStepCard(
        index: 4,
        title: 'Семантический разбор',
        subtitle: 'intent + entities + confidence',
        icon: Icons.psychology_rounded,
        color: Colors.indigo,
        child: _SemanticCommandView(command: r.parsed, label: 'NLP Parse'),
      ));
    }

    if (_visibleSteps >= 5) {
      steps.add(_PipelineStepCard(
        index: 5,
        title: 'Контекст диалога',
        subtitle: r.contextUsed
            ? 'Контекст применён: объединение с предыдущей командой'
            : 'Контекст не потребовался',
        icon: Icons.merge_type_rounded,
        color: r.contextUsed ? Colors.orange : Colors.grey,
        child: r.contextUsed
            ? _SemanticCommandView(
                command: r.resolved,
                label: 'После контекста',
              )
            : Text(
                'Команда полностью самодостаточна',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
      ));
    }

    if (_visibleSteps >= 6) {
      steps.add(_PipelineStepCard(
        index: 6,
        title: 'Результат',
        icon: Icons.check_circle_rounded,
        color: _confidenceColor(r.resolved.confidence),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SemanticCommandView(
              command: r.resolved,
              label: 'Финальная команда',
            ),
            const SizedBox(height: 12),
            _ConfidenceMeter(confidence: r.resolved.confidence),
          ],
        ),
      ));
    }

    return steps;
  }
}

Color _confidenceColor(double c) {
  if (c >= 0.9) return const Color(0xFF16A34A);
  if (c >= 0.6) return const Color(0xFFEA580C);
  return const Color(0xFFDC2626);
}

class _PipelineResult {
  _PipelineResult({
    required this.raw,
    required this.normalized,
    required this.dateEntities,
    required this.priorityEntities,
    required this.parsed,
    required this.resolved,
    required this.contextUsed,
  });

  final String raw;
  final String normalized;
  final Map<String, dynamic> dateEntities;
  final Map<String, dynamic> priorityEntities;
  final SemanticCommand parsed;
  final SemanticCommand resolved;
  final bool contextUsed;
}

class _PipelineStepCard extends StatelessWidget {
  const _PipelineStepCard({
    required this.index,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  final int index;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (index < 6)
                  Container(
                    width: 2,
                    height: 24,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Material(
                elevation: 1,
                shadowColor: scheme.shadow.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 20, color: color),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      child,
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

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _EntityRow extends StatelessWidget {
  const _EntityRow({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.outline),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanticCommandView extends StatelessWidget {
  const _SemanticCommandView({
    required this.command,
    required this.label,
  });

  final SemanticCommand command;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                command.intentCode,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (command.entities.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...command.entities.entries.map(
            (e) => _EntityRow(name: e.key, value: '${e.value}'),
          ),
        ],
      ],
    );
  }
}

class _ConfidenceMeter extends StatelessWidget {
  const _ConfidenceMeter({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _confidenceColor(confidence);
    final pct = (confidence * 100).round();
    final label = confidence >= 0.9
        ? 'Высокая уверенность'
        : confidence >= 0.6
            ? 'Средняя уверенность'
            : 'Низкая уверенность';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$pct%',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: confidence.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              );
            },
          ),
        ),
      ],
    );
  }
}
