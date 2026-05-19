import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command.dart';
import '../../../../core/semantic/semantic_node.dart';
import '../../data/hive_history_repository.dart';
import '../../domain/recorded_command.dart';
import 'command_history_state.dart';

class CommandHistoryCubit extends Cubit<CommandHistoryState> {
  CommandHistoryCubit({HiveHistoryRepository? repository})
      : _repo = repository ?? HiveHistoryRepository(),
        super(const CommandHistoryState()) {
    _restore();
  }

  final HiveHistoryRepository _repo;

  Future<void> _restore() async {
    try {
      final all = await _repo.getAll();
      emit(state.copyWith(items: all));
    } catch (e) {
      debugPrint('[History] restore failed: $e');
    }
  }

  void record(String rawText, SemanticCommand resolved, [SemanticTree? tree]) {
    final entry = RecordedCommand(
      rawText: rawText,
      intentCode: resolved.intentCode,
      entities: Map<String, dynamic>.from(resolved.entities),
      confidence: resolved.confidence,
      at: DateTime.now(),
      treeJson: tree?.toJson(),
    );
    emit(state.copyWith(items: [entry, ...state.items]));
    unawaited(_repo.add(entry));
  }

  Future<void> clear() async {
    emit(const CommandHistoryState());
    await _repo.clear();
  }
}
