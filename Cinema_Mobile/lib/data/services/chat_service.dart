import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatService {
  ChatService({required this.client});

  final ApiClient client;

  Future<String> reply(List<ChatMessage> messages) async {
    final response = await client.post(
      '/api/v1/chat',
      body: {'messages': messages.map((message) => message.toJson()).toList()},
      // AI generation can be billed; only retry when the user asks.
      retryWhenStarting: false,
    );
    if (response is! Map<String, dynamic> ||
        response['message'] is! String ||
        (response['message'] as String).trim().isEmpty) {
      throw const ApiException(
        message: 'Cinema AI returned an invalid response. Please try again.',
      );
    }
    return response['message'] as String;
  }
}
