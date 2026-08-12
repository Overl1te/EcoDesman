import "app_notification.dart";

class NotificationsResponse {
  const NotificationsResponse({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<AppNotification> items;

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      unreadCount: json["unread_count"] as int? ?? 0,
      items: (json["results"] as List<dynamic>? ?? [])
          .map(
            (item) => AppNotification.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
