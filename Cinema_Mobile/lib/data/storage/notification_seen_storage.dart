import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// shortcut: Seen state is device-local; use backend read receipts once available.
class NotificationSeenStorage {
  static const _storage = FlutterSecureStorage();

  Future<int> read(int userId) async =>
      int.tryParse(
        await _storage.read(key: 'notifications.seen.$userId') ?? '',
      ) ??
      0;

  Future<void> markSeen(int userId, int notificationId) async {
    if (notificationId <= await read(userId)) return;
    await _storage.write(
      key: 'notifications.seen.$userId',
      value: notificationId.toString(),
    );
  }
}
