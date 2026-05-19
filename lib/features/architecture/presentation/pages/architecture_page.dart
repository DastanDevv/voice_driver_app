import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/pipeline/pipeline_event.dart';
import '../../../../core/voice/voice_command_coordinator.dart';

/// Живой граф архитектуры Voice-Driven UI: подсвечивает текущий этап пайплайна
/// по мере обработки голосовой команды.
class ArchitecturePage extends StatefulWidget {
  const ArchitecturePage({super.key, required this.voiceCoordinator});

  final VoiceCommandCoordinator voiceCoordinator;

  @override
  State<ArchitecturePage> createState() => _ArchitecturePageState();
}

class _ArchitecturePageState extends State<ArchitecturePage>
    with TickerProviderStateMixin {
  StreamSubscription<PipelineEvent>? _sub;
  final Map<PipelineStage, _StageState> _states = {};
  final List<PipelineEvent> _log = [];

  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    for (final s in PipelineStage.values) {
      _states[s] = _StageState();
    }
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _sub = widget.voiceCoordinator.pipelineEvents.listen(_onEvent);
  }

  void _onEvent(PipelineEvent event) {
    setState(() {
      _states[event.stage] = _StageState(
        activatedAt: event.at,
        active: true,
        payload: event.payload,
      );
      _log.insert(0, event);
      if (_log.length > 30) _log.removeRange(30, _log.length);
    });

    // Деактивация через короткий таймер.
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        final s = _states[event.stage]!;
        if (s.activatedAt == event.at) {
          _states[event.stage] = _StageState(
            activatedAt: s.activatedAt,
            active: false,
            payload: s.payload,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архитектура'),
        actions: [
          if (_log.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded),
              tooltip: 'Очистить лог',
              onPressed: () => setState(_log.clear),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderHint(theme: theme),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PipelineGraph(
                        states: _states,
                        flow: _flowController,
                      ),
                      const SizedBox(height: 16),
                      _EventLogPanel(events: _log),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderHint extends StatelessWidget {
  const _HeaderHint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.tertiaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Скажите команду — узлы графа загорятся по мере прохождения '
              'данных по архитектурному пайплайну в реальном времени.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageState {
  _StageState({this.activatedAt, this.active = false, this.payload});
  final DateTime? activatedAt;
  final bool active;
  final String? payload;
}

class _PipelineGraph extends StatelessWidget {
  const _PipelineGraph({required this.states, required this.flow});

  final Map<PipelineStage, _StageState> states;
  final AnimationController flow;

  static const List<_StageMeta> _meta = [
    _StageMeta(
      stage: PipelineStage.microphone,
      title: 'Микрофон',
      subtitle: 'захват аудио',
      icon: Icons.mic_rounded,
      color: Color(0xFF60A5FA),
    ),
    _StageMeta(
      stage: PipelineStage.speechToText,
      title: 'STT',
      subtitle: 'распознавание речи',
      icon: Icons.transcribe_rounded,
      color: Color(0xFF818CF8),
    ),
    _StageMeta(
      stage: PipelineStage.splitter,
      title: 'Splitter',
      subtitle: 'разделение составных фраз',
      icon: Icons.call_split_rounded,
      color: Color(0xFFA78BFA),
    ),
    _StageMeta(
      stage: PipelineStage.nlpParser,
      title: 'NLP Parser',
      subtitle: 'извлечение намерения',
      icon: Icons.psychology_rounded,
      color: Color(0xFFE879F9),
    ),
    _StageMeta(
      stage: PipelineStage.contextManager,
      title: 'Context Manager',
      subtitle: 'диалоговый контекст',
      icon: Icons.merge_type_rounded,
      color: Color(0xFFFB923C),
    ),
    _StageMeta(
      stage: PipelineStage.semanticTree,
      title: 'Семантическое дерево',
      subtitle: 'построение иерархии',
      icon: Icons.account_tree_rounded,
      color: Color(0xFFFBBF24),
    ),
    _StageMeta(
      stage: PipelineStage.executor,
      title: 'Executor',
      subtitle: 'выполнение команды',
      icon: Icons.play_circle_rounded,
      color: Color(0xFF34D399),
    ),
    _StageMeta(
      stage: PipelineStage.textToSpeech,
      title: 'TTS',
      subtitle: 'голосовой ответ',
      icon: Icons.volume_up_rounded,
      color: Color(0xFF22D3EE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < _meta.length; i++) ...[
              _StageRow(
                meta: _meta[i],
                state: states[_meta[i].stage] ?? _StageState(),
                flow: flow,
                isFirst: i == 0,
                isLast: i == _meta.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageMeta {
  const _StageMeta({
    required this.stage,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final PipelineStage stage;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.meta,
    required this.state,
    required this.flow,
    required this.isFirst,
    required this.isLast,
  });

  final _StageMeta meta;
  final _StageState state;
  final AnimationController flow;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = state.active;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox.shrink()
                      : _Connector(
                          flow: flow,
                          active: active,
                          color: meta.color,
                        ),
                ),
                _NodeCircle(meta: meta, active: active),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : _Connector(
                          flow: flow,
                          active: active,
                          color: meta.color,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active
                      ? meta.color.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? meta.color.withValues(alpha: 0.6)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                    width: active ? 1.5 : 1,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: meta.color.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: active ? meta.color : scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (active)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: meta.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'LIVE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (state.payload != null) ...[
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey(state.payload),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.payload!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCircle extends StatelessWidget {
  const _NodeCircle({required this.meta, required this.active});
  final _StageMeta meta;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? meta.color : meta.color.withValues(alpha: 0.15),
        boxShadow: active
            ? [
                BoxShadow(
                  color: meta.color.withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        meta.icon,
        color: active ? Colors.white : meta.color,
        size: 22,
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({
    required this.flow,
    required this.active,
    required this.color,
  });

  final AnimationController flow;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      child: Center(
        child: AnimatedBuilder(
          animation: flow,
          builder: (context, _) {
            return CustomPaint(
              size: const Size(2, double.infinity),
              painter: _ConnectorPainter(
                flow: flow.value,
                active: active,
                accent: color,
                base: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.flow,
    required this.active,
    required this.accent,
    required this.base,
  });

  final double flow;
  final bool active;
  final Color accent;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = base
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      basePaint,
    );

    if (!active) return;

    const dotCount = 4;
    for (var i = 0; i < dotCount; i++) {
      final phase = (flow + i / dotCount) % 1.0;
      final y = phase * size.height;
      final t = math.sin(phase * math.pi);
      final paint = Paint()
        ..color = accent.withValues(alpha: 0.85 * t)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width / 2, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.flow != flow ||
      oldDelegate.active != active ||
      oldDelegate.accent != accent;
}

class _EventLogPanel extends StatelessWidget {
  const _EventLogPanel({required this.events});

  final List<PipelineEvent> events;

  static const _stageLabels = <PipelineStage, String>{
    PipelineStage.microphone: 'mic',
    PipelineStage.speechToText: 'stt',
    PipelineStage.splitter: 'split',
    PipelineStage.nlpParser: 'parse',
    PipelineStage.contextManager: 'ctx',
    PipelineStage.semanticTree: 'tree',
    PipelineStage.executor: 'exec',
    PipelineStage.textToSpeech: 'tts',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal_rounded,
                    color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Журнал событий',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${events.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (events.isEmpty)
              Text(
                'События появятся после голосовой команды.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final e = events[i];
                    final t = e.at;
                    final hh = t.hour.toString().padLeft(2, '0');
                    final mm = t.minute.toString().padLeft(2, '0');
                    final ss = t.second.toString().padLeft(2, '0');
                    final ms = t.millisecond.toString().padLeft(3, '0');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            '$hh:$mm:$ss.$ms',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _stageLabels[e.stage] ?? e.stage.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.payload ?? '',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
