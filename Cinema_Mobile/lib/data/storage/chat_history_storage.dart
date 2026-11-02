import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/chat_service.dart';

class SavedChat {
  const SavedChat({
    required this.id,
    required this.updatedAt,
    required this.messages,
  });
  final String id;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  String get title => messages.first.content;
  Map<String, Object?> toJson() => {
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((message) => message.toJson()).toList(),
  };
}

class ChatHistory {
  const ChatHistory({this.activeId, this.chats = const []});
  final String? activeId;
  final List<SavedChat> chats;
}

class ChatHistoryStorage {
  ChatHistoryStorage({required int? userId, FlutterSecureStorage? storage})
    : _key = 'cinema.chat.v1.${userId == null ? 'guest' : 'user.$userId'}',
      _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;
  Future<void> _writes = Future.value();

  Future<ChatHistory> read() async {
    await _writes;
    final raw = await _storage.read(key: _key);
    if (raw == null) return const ChatHistory();
    try {
      if (raw.length > 6000000) {
        throw const FormatException('History too large');
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final chats = <SavedChat>[];
      for (final entry in (data['chats'] as List).take(20)) {
        final item = entry as Map<String, dynamic>;
        final messages = <ChatMessage>[];
        final values = item['messages'] as List;
        if (values.isEmpty || values.length > 60 || values.length.isOdd) {
          continue;
        }
        for (final (index, value) in values.indexed) {
          if (value['role'] != (index.isEven ? 'user' : 'assistant') ||
              value['content'] is! String ||
              (value['content'] as String).trim().isEmpty ||
              (value['content'] as String).length > 4000) {
            throw const FormatException('Invalid saved conversation');
          }
          messages.add(
            ChatMessage(
              role: value['role'] as String,
              content: value['content'] as String,
            ),
          );
        }
        final id = item['id'] as String;
        if (id.isEmpty ||
            id.length > 100 ||
            chats.any((chat) => chat.id == id)) {
          continue;
        }
        chats.add(
          SavedChat(
            id: id,
            updatedAt: DateTime.parse(item['updatedAt'] as String),
            messages: messages,
          ),
        );
      }
      final activeId = data['activeId'] as String?;
      return ChatHistory(
        activeId: chats.any((chat) => chat.id == activeId) ? activeId : null,
        chats: chats,
      );
    } on FormatException {
      return const ChatHistory();
    } on TypeError {
      return const ChatHistory();
    } on NoSuchMethodError {
      return const ChatHistory();
    }
  }

  Future<void> save(ChatHistory history) {
    // Keep rapid New chat, reply and deletion writes in their original order.
    final data = jsonEncode({
      'activeId': history.activeId,
      'chats': history.chats.take(20).map((chat) => chat.toJson()).toList(),
    });
    final write = _writes.then((_) => _storage.write(key: _key, value: data));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
