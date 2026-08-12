import "../models/app_notification.dart";
import "../models/notifications_response.dart";

abstract class NotificationsRepository {
  Future<NotificationsResponse> fetchNotifications();

  Future<AppNotification> markRead(int notificationId);

  Future<void> markAllRead();
}
