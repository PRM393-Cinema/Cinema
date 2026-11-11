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

  Future<String> reply(List<ChatMessage> messages) async =>
      (await replyWithActions(messages)).message;

  Future<ChatResponse> replyWithActions(
    List<ChatMessage> messages, {
    bool authenticated = false,
  }) async {
    final response = await client.post(
      authenticated ? '/api/v1/chat/account' : '/api/v1/chat',
      authenticated: authenticated,
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
    return ChatResponse(
      response['message'] as String,
      response['booking'] is Map<String, dynamic>
          ? ChatBookingProposal.fromJson(
              response['booking'] as Map<String, dynamic>,
            )
          : null,
      bookingForm: switch (response['bookingForm']) {
        final Map<String, dynamic> json => ChatBookingForm(
          movie: json['movie'] as String?,
          date: json['date'] as String?,
          time: json['time'] as String?,
          tickets: json['tickets'] as int?,
        ),
        _ => null,
      },
      showtimeTickets: {
        if (response['showtimeTickets'] case final Map<String, dynamic> values)
          for (final entry in values.entries)
            if (entry.value is int &&
                (entry.value as int) >= 1 &&
                (entry.value as int) <= 8)
              entry.key: entry.value as int,
      },
    );
  }
}

class ChatResponse {
  const ChatResponse(
    this.message,
    this.booking, {
    this.bookingForm,
    this.showtimeTickets = const {},
  });
  final String message;
  final ChatBookingProposal? booking;
  final ChatBookingForm? bookingForm;
  final Map<String, int> showtimeTickets;
}

class ChatBookingForm {
  const ChatBookingForm({this.movie, this.date, this.time, this.tickets});
  final String? movie;
  final String? date;
  final String? time;
  final int? tickets;
}

class ChatBookingProposal {
  const ChatBookingProposal({
    required this.movieId,
    required this.showtimeId,
    required this.movieTitle,
    required this.seatIds,
    required this.total,
    required this.expiresAt,
  });
  factory ChatBookingProposal.fromJson(Map<String, dynamic> json) {
    final ids = (json['seatIds'] as List).cast<int>();
    final total = (json['total'] as num).toDouble();
    if (json['movieId'] is! int ||
        (json['movieId'] as int) <= 0 ||
        json['showtimeId'] is! int ||
        (json['showtimeId'] as int) <= 0 ||
        json['movieTitle'] is! String ||
        ids.isEmpty ||
        ids.length > 8 ||
        ids.any((id) => id <= 0) ||
        ids.toSet().length != ids.length ||
        !total.isFinite ||
        total < 0) {
      throw const FormatException('Invalid booking proposal.');
    }
    return ChatBookingProposal(
      movieId: json['movieId'] as int,
      showtimeId: json['showtimeId'] as int,
      movieTitle: json['movieTitle'] as String,
      seatIds: List.unmodifiable(ids),
      total: total,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
  final int movieId;
  final int showtimeId;
  final String movieTitle;
  final List<int> seatIds;
  final double total;
  final DateTime expiresAt;
}
