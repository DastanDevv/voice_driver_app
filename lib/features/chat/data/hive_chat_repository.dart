import '../../../core/storage/hive_storage.dart';
import '../domain/chat_message.dart';

/// Постоянное хранилище сообщений чата (диалог пользователя и ассистента).
class HiveChatRepository {
  HiveChatRepository();

  Future<List<ChatMessage>> getAll() async {
    final box = HiveStorage.chatBox();
    final msgs = box.values
        .map((m) => ChatMessage.fromJson(m.cast<String, dynamic>()))
        .toList();
    msgs.sort((a, b) => a.at.compareTo(b.at));
    return msgs;
  }

  Future<void> add(ChatMessage msg) async {
    final box = HiveStorage.chatBox();
    await box.put(msg.id, msg.toJson());
  }

  Future<void> clear() async {
    final box = HiveStorage.chatBox();
    await box.clear();
  }
}
