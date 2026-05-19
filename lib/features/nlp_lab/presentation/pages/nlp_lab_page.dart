import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/nlp/command_splitter.dart';
import '../../../../core/nlp/russian_nlp_engine.dart';
import '../../../../core/semantic/context_manager.dart';
import '../../../../core/semantic/semantic_command.dart';
import '../../../../core/semantic/semantic_node.dart';
import '../../../../core/semantic/semantic_tree_builder.dart';
import '../../../../shared/strings/app_strings.dart';
import '../../../architecture/presentation/pages/architecture_page.dart';
import '../../../../core/voice/voice_command_coordinator.dart';
import '../widgets/semantic_tree_view.dart';

/// NLP-лаборатория: визуализация пайплайна и семантического дерева.
class NlpLabPage extends StatefulWidget {
  const NlpLabPage({super.key, this.voiceCoordinator});

  final VoiceCommandCoordinator? voiceCoordinator;

  @override
  State<NlpLabPage> createState() => _NlpLabPageState();
}

class _NlpLabPageState extends State<NlpLabPage>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _engine = RussianNlpEngine();
  final _contextManager = ContextManager();
  final _treeBuilder = const SemanticTreeBuilder();
  final _splitter = const CommandSplitter();

  late final TabController _tab;
  _PipelineResult? _result;
  List<_PipelineResult> _multiResults = const [];
  int _visibleSteps = 0;
  Timer? _stepTimer;

  static const _samplePhrases = [
    'Создай задачу купить хлеб на завтра',
    'Покажи важные задачи',
    'Добавь срочную задачу подготовить презентацию',
    'Выполни задачу купить хлеб',
    'Создай задачу позвонить маме через два часа',
    'Найди задачу презентацию',
    'Сколько задач',
    'Очисти выполненные',
    'Открой аналитику',
    'Включи тёмную тему',
    'Создай задачу купить молоко и удали задачу хлеб а потом покажи задачи',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _stepTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _analyze(String text) {
    if (text.trim().isEmpty) return;
    _stepTimer?.cancel();

    final raw = text.trim();
    final segments = _splitter.split(raw);
    final multi = segments
        .map((seg) => _buildPipelineResult(seg))
        .toList(growable: false);

    setState(() {
      _multiResults = multi;
      _result = multi.isNotEmpty ? multi.first : null;
      _visibleSteps = 0;
    });

    _stepTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _visibleSteps++);
      if (_visibleSteps >= 7) timer.cancel();
    });
  }

  _PipelineResult _buildPipelineResult(String raw) {
    final normalized = _engine.normalize(raw);
    final parsed = _engine.parse(raw);
    final dateEntities = _engine.extractDate(normalized);
    final priorityEntities = <String, dynamic>{};
    _engine.extractPriority(normalized, priorityEntities);
    final resolved = _contextManager.applyContext(parsed);
    final tree = _treeBuilder.build(
      rawText: raw,
      normalizedText: normalized,
      command: resolved,
      tokens: normalized.split(' ').where((t) => t.isNotEmpty).toList(),
    );

    return _PipelineResult(
      raw: raw,
      normalized: normalized,
      dateEntities: dateEntities,
      priorityEntities: priorityEntities,
      parsed: parsed,
      resolved: resolved,
      tree: tree,
      contextUsed: resolved.intentCode != parsed.intentCode ||
          resolved.entities.length != parsed.entities.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = _result;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar.large(
            title: const Text(AppStrings.nlpLabTitle),
            centerTitle: false,
            actions: [
              if (widget.voiceCoordinator != null)
                IconButton(
                  tooltip: 'Живой граф архитектуры',
                  icon: const Icon(Icons.bolt_rounded),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ArchitecturePage(
                          voiceCoordinator: widget.voiceCoordinator!,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _InputCard(
                controller: _controller,
                onAnalyze: _analyze,
                samples: _samplePhrases,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              tabBar: TabBar(
                controller: _tab,
                isScrollable: false,
                indicator: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                labelColor: scheme.onPrimaryContainer,
                unselectedLabelColor: scheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                dividerHeight: 0,
                tabs: const [
                  Tab(text: 'Дерево'),
                  Tab(text: 'Пайплайн'),
                  Tab(text: 'Токены'),
                ],
              ),
              background: scheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _TreeTab(
              result: result,
              multi: _multiResults,
              theme: theme,
            ),
            _PipelineTab(
              result: result,
              visibleSteps: _visibleSteps,
              theme: theme,
            ),
            _TokensTab(result: result, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  _StickyTabBarDelegate({required this.tabBar, required this.background});
  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar || oldDelegate.background != background;
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.controller,
    required this.onAnalyze,
    required this.samples,
  });

  final TextEditingController controller;
  final void Function(String) onAnalyze;
  final List<String> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 0,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: AppStrings.nlpLabHint,
                prefixIcon: Icon(Icons.science_rounded, color: scheme.primary),
                suffixIcon: FilledButton.icon(
                  onPressed: () => onAnalyze(controller.text),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Разобрать'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
                suffixIconConstraints:
                    const BoxConstraints(minHeight: 48, minWidth: 130),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: onAnalyze,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: samples.map((phrase) {
                return ActionChip(
                  label: Text(
                    phrase,
                    style: theme.textTheme.labelMedium,
                  ),
                  onPressed: () {
                    controller.text = phrase;
                    onAnalyze(phrase);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeTab extends StatelessWidget {
  const _TreeTab({
    required this.result,
    required this.multi,
    required this.theme,
  });
  final _PipelineResult? result;
  final List<_PipelineResult> multi;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _EmptyLabHint(theme: theme);
    }
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (multi.length > 1) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.call_split_rounded, color: scheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Составной запрос разбит на ${multi.length} команд(ы):',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < multi.length; i++) ...[
            _TreeBlock(result: multi[i], index: i + 1, theme: theme),
            const SizedBox(height: 18),
          ],
        ] else
          _TreeBlock(result: result!, index: null, theme: theme),
      ],
    );
  }
}

class _TreeBlock extends StatelessWidget {
  const _TreeBlock({
    required this.result,
    required this.index,
    required this.theme,
  });
  final _PipelineResult result;
  final int? index;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final tree = result.tree;
    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        index == null
                            ? 'Семантическое дерево'
                            : 'Команда #$index: ${tree.intentCode}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '«${tree.rawText}»',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TreeStatChip(
                  icon: Icons.hub_rounded,
                  label: 'узлов',
                  value: '${tree.nodeCount}',
                  color: scheme.primary,
                ),
                _TreeStatChip(
                  icon: Icons.height_rounded,
                  label: 'глубина',
                  value: '${tree.depth}',
                  color: scheme.tertiary,
                ),
                _TreeStatChip(
                  icon: Icons.eco_rounded,
                  label: 'листьев',
                  value: '${tree.leafCount}',
                  color: scheme.secondary,
                ),
                _TreeStatChip(
                  icon: Icons.speed_rounded,
                  label: 'уверенность',
                  value: '${(tree.confidence * 100).round()}%',
                  color: _confidenceColor(tree.confidence),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SemanticTreeView(tree: tree),
            const SizedBox(height: 12),
            const _TreeLegend(),
          ],
        ),
      ),
    );
  }
}

class _TreeStatChip extends StatelessWidget {
  const _TreeStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreeLegend extends StatelessWidget {
  const _TreeLegend();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: const [
          _LegendItem(color: Color(0xFF6366F1), label: 'ROOT'),
          _LegendItem(color: Color(0xFFEF4444), label: 'ACTION'),
          _LegendItem(color: Color(0xFF10B981), label: 'OBJECT'),
          _LegendItem(color: Color(0xFFF59E0B), label: 'MODIFIER'),
          _LegendItem(color: Color(0xFF6B7280), label: 'VALUE'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _PipelineTab extends StatelessWidget {
  const _PipelineTab({
    required this.result,
    required this.visibleSteps,
    required this.theme,
  });
  final _PipelineResult? result;
  final int visibleSteps;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (result == null) return _EmptyLabHint(theme: theme);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: _buildSteps(context, result!),
    );
  }

  List<Widget> _buildSteps(BuildContext context, _PipelineResult r) {
    final steps = <Widget>[];

    if (visibleSteps >= 1) {
      steps.add(_PipelineStepCard(
        index: 1,
        title: 'Входной текст',
        icon: Icons.text_fields_rounded,
        color: const Color(0xFF64748B),
        child: _CodeBlock(text: '"${r.raw}"'),
      ));
    }

    if (visibleSteps >= 2) {
      steps.add(_PipelineStepCard(
        index: 2,
        title: 'Нормализация',
        subtitle: 'lowercase, ё→е, trim, collapse spaces',
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF14B8A6),
        child: _CodeBlock(text: '"${r.normalized}"'),
      ));
    }

    if (visibleSteps >= 3) {
      steps.add(_PipelineStepCard(
        index: 3,
        title: 'Извлечение сущностей',
        subtitle: 'дата, время, приоритет',
        icon: Icons.account_tree_rounded,
        color: const Color(0xFF7C3AED),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...r.dateEntities.entries.map(
              (e) => _EntityRow(name: e.key, value: '${e.value}'),
            ),
            ...r.priorityEntities.entries.map(
              (e) => _EntityRow(name: e.key, value: '${e.value}'),
            ),
            if (r.dateEntities.isEmpty && r.priorityEntities.isEmpty)
              Text(
                'Сущностей не найдено',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ));
    }

    if (visibleSteps >= 4) {
      steps.add(_PipelineStepCard(
        index: 4,
        title: 'Семантический разбор',
        subtitle: 'intent + entities + confidence',
        icon: Icons.psychology_rounded,
        color: const Color(0xFF4F46E5),
        child: _SemanticCommandView(command: r.parsed, label: 'NLP Parse'),
      ));
    }

    if (visibleSteps >= 5) {
      steps.add(_PipelineStepCard(
        index: 5,
        title: 'Контекст диалога',
        subtitle: r.contextUsed
            ? 'Контекст применён: объединение с предыдущей командой'
            : 'Контекст не потребовался',
        icon: Icons.merge_type_rounded,
        color: r.contextUsed
            ? const Color(0xFFF97316)
            : const Color(0xFF94A3B8),
        child: r.contextUsed
            ? _SemanticCommandView(
                command: r.resolved,
                label: 'После контекста',
              )
            : Text(
                'Команда полностью самодостаточна',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ));
    }

    if (visibleSteps >= 6) {
      steps.add(_PipelineStepCard(
        index: 6,
        title: 'Семантическое дерево',
        subtitle: 'Иерархия: ROOT → ACTION → OBJECT → MODIFIERS',
        icon: Icons.account_tree_rounded,
        color: const Color(0xFFEAB308),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Узлов: ${r.tree.nodeCount} · Глубина: ${r.tree.depth} · Листьев: ${r.tree.leafCount}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SemanticTreeView(tree: r.tree),
          ],
        ),
      ));
    }

    if (visibleSteps >= 7) {
      steps.add(_PipelineStepCard(
        index: 7,
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

class _TokensTab extends StatelessWidget {
  const _TokensTab({required this.result, required this.theme});
  final _PipelineResult? result;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (result == null) return _EmptyLabHint(theme: theme);
    final scheme = theme.colorScheme;
    final tokens =
        result!.normalized.split(' ').where((t) => t.isNotEmpty).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          elevation: 1,
          shadowColor: scheme.shadow.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Токенизация (${tokens.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < tokens.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: 0.18),
                              scheme.tertiary.withValues(alpha: 0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${i + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tokens[i],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Сущности',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (result!.resolved.entities.isEmpty)
                  Text(
                    'нет',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final e in result!.resolved.entities.entries)
                    _EntityRow(name: e.key, value: '${e.value}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyLabHint extends StatelessWidget {
  const _EmptyLabHint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: const Icon(
              Icons.account_tree_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'NLP Лаборатория',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Введите фразу или выберите пример — увидите семантическое дерево '
          'и пошаговый разбор.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
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
    required this.tree,
    required this.contextUsed,
  });

  final String raw;
  final String normalized;
  final Map<String, dynamic> dateEntities;
  final Map<String, dynamic> priorityEntities;
  final SemanticCommand parsed;
  final SemanticCommand resolved;
  final SemanticTree tree;
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
            offset: Offset(0, 16 * (1 - value)),
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
                shadowColor: scheme.shadow.withValues(alpha: 0.06),
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
  const _SemanticCommandView({required this.command, required this.label});
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
