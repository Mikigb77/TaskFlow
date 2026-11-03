import 'package:agenda/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no reminder shows under id 1, the meeting recorder’s notification', () {
    for (final row in [1, 2, 3, 400, 123456]) {
      final id = reminderNotificationId(row);
      expect(id, isNot(1));
      expect(reminderOfNotification(id), row);
    }
    // One scheduled under id 1 before it moved is still row 1's.
    expect(reminderOfNotification(1), 1);
  });
}
