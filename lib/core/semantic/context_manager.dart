import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'semantic_command.dart';
import 'semantic_context.dart';

/// Хранит контекст диалога и склеивает короткие уточнения с предыдущей командой.
class ContextManager {
  SemanticContext _context = const SemanticContext();

  SemanticContext get snapshot => _context;

  /// После разбора: подмешать предыдущий intent/сущности при необходимости.
  SemanticCommand applyContext(SemanticCommand incoming) {
    debugPrint(
      '[Context] before: intent=${_context.lastIntent} '
      'entities=${_context.lastEntities}',
    );

    final SemanticCommand resolved = _resolve(incoming);

    debugPrint(
      '[Context] after: intent=${resolved.intentCode} '
      'entities=${resolved.entities}',
    );

    _commitAfter(resolved, incoming);
    return resolved;
  }

  SemanticCommand _resolve(SemanticCommand incoming) {
    if (incoming.intentCode == 'create_task' ||
        incoming.intentCode == 'complete_task') {
      return incoming;
    }

    if (incoming.intentCode == 'unknown' && incoming.entities.isNotEmpty) {
      final lastIntent = _context.lastIntent;
      if (lastIntent != null && lastIntent != 'unknown') {
        final merged = Map<String, dynamic>.from(_context.lastEntities);
        merged.addAll(incoming.entities);
        return SemanticCommand(
          intentCode: lastIntent,
          entities: merged,
          confidence: math.min(incoming.confidence, 0.9),
        );
      }
    }

    return incoming;
  }

  void _commitAfter(SemanticCommand resolved, SemanticCommand incoming) {
    if (incoming.intentCode == 'complete_task') {
      _context = const SemanticContext();
      return;
    }

    if (incoming.intentCode == 'create_task') {
      _context = SemanticContext(
        lastIntent: resolved.intentCode,
        lastEntities: Map<String, dynamic>.from(resolved.entities),
      );
      return;
    }

    if (resolved.intentCode == 'unknown') {
      return;
    }

    _context = SemanticContext(
      lastIntent: resolved.intentCode,
      lastEntities: Map<String, dynamic>.from(resolved.entities),
    );
  }
}
