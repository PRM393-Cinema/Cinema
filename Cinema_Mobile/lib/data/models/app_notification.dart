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
    this.readAt,
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
      readAt: readDateTime(json['readAt']),
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

  // When the customer opened it in the app; null while unread.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    bookingId: bookingId,
    subject: subject,
    type: type,
    content: content,
    status: status,
    sentAt: sentAt,
    createdAt: createdAt,
    readAt: readAt ?? at,
  );

  String get plainContent => htmlToPlainText(content);
}
