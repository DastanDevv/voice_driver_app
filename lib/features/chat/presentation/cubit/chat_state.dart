import 'package:equatable/equatable.dart';

import '../../domain/chat_message.dart';

class ChatState extends Equatable {
  const ChatState({this.messages = const [], this.assistantTyping = false});

  final List<ChatMessage> messages;
  final bool assistantTyping;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? assistantTyping,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      assistantTyping: assistantTyping ?? this.assistantTyping,
    );
  }

  @override
  List<Object?> get props => [messages, assistantTyping];
}
