import '../../../core/storage/hive_storage.dart';
import '../domain/recorded_command.dart';

/// Постоянное хранилище истории распознанных команд.
class HiveHistoryRepository {
  HiveHistoryRepository();

  Map<String, dynamic> _serialize(RecordedCommand r) => {
        'rawText': r.rawText,
        'intentCode': r.intentCode,
        'entities': r.entities,
        'confidence': r.confidence,
        'at': r.at.toIso8601String(),
        if (r.treeJson != null) 'treeJson': r.treeJson,
      };

  RecordedCommand _deserialize(Map<dynamic, dynamic> m) {
    return RecordedCommand(
      rawText: m['rawText'] as String,
      intentCode: m['intentCode'] as String,
      entities: (m['entities'] as Map?)?.cast<String, dynamic>() ?? const {},
      confidence: (m['confidence'] as num).toDouble(),
      at: DateTime.parse(m['at'] as String),
      treeJson:
          (m['treeJson'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Future<List<RecordedCommand>> getAll() async {
    final box = HiveStorage.historyBox();
    final all = box.values.map(_deserialize).toList();
    all.sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  Future<void> add(RecordedCommand c) async {
    final box = HiveStorage.historyBox();
    await box.add(_serialize(c));
  }

  Future<void> clear() async {
    final box = HiveStorage.historyBox();
    await box.clear();
  }
}
