import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/semantic/semantic_command.dart';
import '../../data/hive_chat_repository.dart';
import '../../domain/chat_message.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({HiveChatRepository? repository, Uuid? uuid})
      : _repo = repository ?? HiveChatRepository(),
        _uuid = uuid ?? const Uuid(),
        super(const ChatState()) {
    _restore();
  }

  final HiveChatRepository _repo;
  final Uuid _uuid;

  Future<void> _restore() async {
    try {
      final all = await _repo.getAll();
      emit(state.copyWith(messages: all));
    } catch (e) {
      debugPrint('[Chat] restore failed: $e');
    }
  }

  void appendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      text: text.trim(),
      at: DateTime.now(),
    );
    emit(
      state.copyWith(
        messages: [...state.messages, msg],
        assistantTyping: true,
      ),
    );
    unawaited(_repo.add(msg));
  }

  void appendAssistantMessage(
    String text, {
    SemanticCommand? command,
  }) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      text: text,
      at: DateTime.now(),
      intentCode: command?.intentCode,
      confidence: command?.confidence,
      entities: command != null
          ? Map<String, dynamic>.from(command.entities)
          : const {},
    );
    emit(
      state.copyWith(
        messages: [...state.messages, msg],
        assistantTyping: false,
      ),
    );
    unawaited(_repo.add(msg));
  }

  void setTyping(bool typing) {
    emit(state.copyWith(assistantTyping: typing));
  }

  Future<void> clear() async {
    emit(const ChatState());
    await _repo.clear();
  }
}
