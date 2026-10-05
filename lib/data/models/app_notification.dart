import '../../core/utils/html_text.dart';
import 'json_readers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    this.bookingId,
    required this.subject,
    required this.type,
    required this.content,
    required this.status,
    this.sentAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, Object?> json) {
    return AppNotification(
      id: readInt(json['id']),
      bookingId: readOptionalInt(json['bookingId']),
      subject: readString(json['subject']),
      type: readString(json['type']),
      content: readString(json['content']),
      status: readString(json['status']),
      sentAt: readDateTime(json['sentAt']),
      createdAt: readRequiredDateTime(json['createdAt']),
    );
  }

  final int id;
  final int? bookingId;
  final String subject;
  final String type;

  // HTML body of the email that was sent to the customer.
  final String content;
  final String status; // 'PENDING', 'SENT', 'FAILED'
  final DateTime? sentAt;
  final DateTime createdAt;

  String get plainContent => htmlToPlainText(content);
}
