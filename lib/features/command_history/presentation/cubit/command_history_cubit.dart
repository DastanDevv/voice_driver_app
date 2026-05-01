import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command.dart';
import '../../domain/recorded_command.dart';
import 'command_history_state.dart';

class CommandHistoryCubit extends Cubit<CommandHistoryState> {
  CommandHistoryCubit() : super(const CommandHistoryState());

  void record(String rawText, SemanticCommand resolved) {
    final entry = RecordedCommand(
      rawText: rawText,
      intentCode: resolved.intentCode,
      entities: Map<String, dynamic>.from(resolved.entities),
      confidence: resolved.confidence,
      at: DateTime.now(),
    );
    emit(state.copyWith(items: [entry, ...state.items]));
  }

  void clear() {
    emit(const CommandHistoryState());
  }
}
