import 'package:equatable/equatable.dart';

import '../../domain/recorded_command.dart';

class CommandHistoryState extends Equatable {
  const CommandHistoryState({this.items = const []});

  final List<RecordedCommand> items;

  CommandHistoryState copyWith({List<RecordedCommand>? items}) {
    return CommandHistoryState(items: items ?? this.items);
  }

  @override
  List<Object?> get props => [items];
}
