import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant, system }

/// Сообщение в диалоге между пользователем и ассистентом.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.intentCode,
    this.confidence,
    this.entities = const {},
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime at;

  final String? intentCode;
  final double? confidence;
  final Map<String, dynamic> entities;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': at.toIso8601String(),
        if (intentCode != null) 'intentCode': intentCode,
        if (confidence != null) 'confidence': confidence,
        if (entities.isNotEmpty) 'entities': entities,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => ChatRole.user,
      ),
      text: json['text'] as String,
      at: DateTime.parse(json['at'] as String),
      intentCode: json['intentCode'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      entities: (json['entities'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @override
  List<Object?> get props => [id, role, text, at, intentCode, confidence, entities];
}
