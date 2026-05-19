import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../../../core/semantic/semantic_node.dart';

/// Визуализация семантического дерева как top-down иерархии (Buchheim-Walker).
///
/// Это центральная демо-точка диплома: показывает корень → ACTION → OBJECT → MODIFIERS → VALUE
/// с цветовой кодировкой типа узла и пульсирующей анимацией появления.
class SemanticTreeView extends StatefulWidget {
  const SemanticTreeView({super.key, required this.tree});

  final SemanticTree tree;

  @override
  State<SemanticTreeView> createState() => _SemanticTreeViewState();
}

class _SemanticTreeViewState extends State<SemanticTreeView>
    with SingleTickerProviderStateMixin {
  late Graph _graph;
  late BuchheimWalkerConfiguration _config;
  late final AnimationController _controller;

  final Map<int, SemanticNode> _nodesByKey = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _buildGraph();
  }

  @override
  void didUpdateWidget(covariant SemanticTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tree != widget.tree) {
      _buildGraph();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _buildGraph() {
    _graph = Graph()..isTree = true;
    _nodesByKey.clear();
    var idCounter = 0;

    Node addNode(SemanticNode sn) {
      final key = idCounter++;
      _nodesByKey[key] = sn;
      final node = Node.Id(key);
      _graph.addNode(node);
      return node;
    }

    void walk(SemanticNode sn, Node parent) {
      for (final child in sn.children) {
        final cn = addNode(child);
        _graph.addEdge(parent, cn);
        walk(child, cn);
      }
    }

    final rootNode = addNode(widget.tree.root);
    walk(widget.tree.root, rootNode);

    _config = BuchheimWalkerConfiguration()
      ..siblingSeparation = 28
      ..levelSeparation = 48
      ..subtreeSeparation = 40
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        height: 360,
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(80),
          minScale: 0.4,
          maxScale: 2.2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return GraphView(
                graph: _graph,
                algorithm: BuchheimWalkerAlgorithm(
                  _config,
                  TreeEdgeRenderer(_config),
                ),
                paint: Paint()
                  ..color = scheme.primary.withValues(alpha: 0.55)
                  ..strokeWidth = 1.4
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  final key = node.key!.value as int;
                  final semanticNode = _nodesByKey[key]!;
                  return _SemanticNodeChip(
                    node: semanticNode,
                    appearance: _controller.value,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SemanticNodeChip extends StatelessWidget {
  const _SemanticNodeChip({
    required this.node,
    required this.appearance,
  });

  final SemanticNode node;
  final double appearance;

  Color _colorFor(SemanticNodeType t, ColorScheme scheme) {
    switch (t) {
      case SemanticNodeType.root:
        return const Color(0xFF6366F1);
      case SemanticNodeType.action:
        return const Color(0xFFEF4444);
      case SemanticNodeType.object:
        return const Color(0xFF10B981);
      case SemanticNodeType.modifier:
        return const Color(0xFFF59E0B);
      case SemanticNodeType.value:
        return const Color(0xFF6B7280);
    }
  }

  IconData _iconFor(SemanticNodeType t) {
    switch (t) {
      case SemanticNodeType.root:
        return Icons.account_tree_rounded;
      case SemanticNodeType.action:
        return Icons.flash_on_rounded;
      case SemanticNodeType.object:
        return Icons.inventory_2_rounded;
      case SemanticNodeType.modifier:
        return Icons.tune_rounded;
      case SemanticNodeType.value:
        return Icons.label_rounded;
    }
  }

  String _typeLabel(SemanticNodeType t) {
    switch (t) {
      case SemanticNodeType.root:
        return 'ROOT';
      case SemanticNodeType.action:
        return 'ACTION';
      case SemanticNodeType.object:
        return 'OBJECT';
      case SemanticNodeType.modifier:
        return 'MODIFIER';
      case SemanticNodeType.value:
        return 'VALUE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _colorFor(node.type, scheme);
    final scale = (0.6 + 0.4 * appearance).clamp(0.0, 1.0);

    return Opacity(
      opacity: appearance,
      child: Transform.scale(
        scale: scale,
        child: Container(
          constraints: const BoxConstraints(minWidth: 60, maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(node.type), size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    _typeLabel(node.type),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                node.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (node.value != null && node.value!.isNotEmpty &&
                  node.value != node.label)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    node.value!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
