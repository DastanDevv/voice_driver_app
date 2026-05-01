import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/strings/app_strings.dart';
import '../../../command_history/domain/recorded_command.dart';
import '../../../command_history/presentation/cubit/command_history_cubit.dart';
import '../../../command_history/presentation/cubit/command_history_state.dart';

/// Дашборд аналитики распознавания: метрики + визуализации.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CommandHistoryCubit, CommandHistoryState>(
        builder: (context, state) {
          if (state.items.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverAppBar.large(
                  title: const Text(AppStrings.analyticsTitle),
                  centerTitle: false,
                ),
                SliverFillRemaining(
                  child: _EmptyAnalytics(),
                ),
              ],
            );
          }
          final stats = _Stats.from(state.items);
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text(AppStrings.analyticsTitle),
                centerTitle: false,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _MetricsRow(stats: stats),
                    const SizedBox(height: 20),
                    _IntentDistribution(stats: stats),
                    const SizedBox(height: 20),
                    _ConfidenceDistribution(stats: stats),
                    const SizedBox(height: 20),
                    _RecentActivity(items: state.items),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stats {
  _Stats({
    required this.total,
    required this.successRate,
    required this.avgConfidence,
    required this.intentCounts,
    required this.highConfidence,
    required this.medConfidence,
    required this.lowConfidence,
  });

  factory _Stats.from(List<RecordedCommand> items) {
    final total = items.length;
    final success = items.where((i) => i.intentCode != 'unknown').length;
    final avgConf = items.fold<double>(0, (s, i) => s + i.confidence) / total;
    final intents = <String, int>{};
    var high = 0;
    var med = 0;
    var low = 0;
    for (final item in items) {
      intents[item.intentCode] = (intents[item.intentCode] ?? 0) + 1;
      if (item.confidence >= 0.9) {
        high++;
      } else if (item.confidence >= 0.6) {
        med++;
      } else {
        low++;
      }
    }
    return _Stats(
      total: total,
      successRate: total > 0 ? success / total : 0,
      avgConfidence: avgConf,
      intentCounts: intents,
      highConfidence: high,
      medConfidence: med,
      lowConfidence: low,
    );
  }

  final int total;
  final double successRate;
  final double avgConfidence;
  final Map<String, int> intentCounts;
  final int highConfidence;
  final int medConfidence;
  final int lowConfidence;
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Всего команд',
            value: '${stats.total}',
            icon: Icons.analytics_rounded,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Распознано',
            value: '${(stats.successRate * 100).round()}%',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Ср. уверенность',
            value: stats.avgConfidence.toStringAsFixed(2),
            icon: Icons.speed_rounded,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentDistribution extends StatelessWidget {
  const _IntentDistribution({required this.stats});

  final _Stats stats;

  static const _intentColors = <String, Color>{
    'create_task': Colors.blue,
    'show_tasks': Colors.teal,
    'complete_task': Colors.green,
    'delete_task': Colors.orange,
    'search_task': Colors.indigo,
    'count_tasks': Colors.purple,
    'clear_completed': Colors.brown,
    'help': Colors.cyan,
    'navigate': Colors.blueGrey,
    'theme_toggle': Colors.amber,
    'undo': Colors.pink,
    'unknown': Colors.red,
  };

  static const _intentLabels = <String, String>{
    'create_task': 'Создание',
    'show_tasks': 'Показ',
    'complete_task': 'Выполнение',
    'delete_task': 'Удаление',
    'search_task': 'Поиск',
    'count_tasks': 'Подсчёт',
    'clear_completed': 'Очистка',
    'help': 'Помощь',
    'navigate': 'Навигация',
    'theme_toggle': 'Тема',
    'undo': 'Отмена',
    'unknown': 'Не распознано',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final sorted = stats.intentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Распределение намерений',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ...sorted.map((entry) {
              final color = _intentColors[entry.key] ?? Colors.grey;
              final label = _intentLabels[entry.key] ?? entry.key;
              final fraction =
                  stats.total > 0 ? entry.value / stats.total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${entry.value} (${(fraction * 100).round()}%)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: fraction),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceDistribution extends StatelessWidget {
  const _ConfidenceDistribution({required this.stats});

  final _Stats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = math.max(stats.total, 1);

    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Распределение уверенности',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _BarSegment(
              label: 'Высокая (≥90%)',
              count: stats.highConfidence,
              total: total,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 10),
            _BarSegment(
              label: 'Средняя (60–89%)',
              count: stats.medConfidence,
              total: total,
              color: const Color(0xFFEA580C),
            ),
            const SizedBox(height: 10),
            _BarSegment(
              label: 'Низкая (<60%)',
              count: stats.lowConfidence,
              total: total,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  const _BarSegment({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text(
              '$count',
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.items});

  final List<RecordedCommand> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recent = items.take(5).toList();

    return Material(
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Последние команды',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...recent.map((item) {
              final color = item.confidence >= 0.9
                  ? const Color(0xFF16A34A)
                  : item.confidence >= 0.6
                      ? const Color(0xFFEA580C)
                      : const Color(0xFFDC2626);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.rawText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.intentCode,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 72,
              color: scheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.analyticsEmpty,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.analyticsEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
