import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/network/api_client.dart";
import "../../domain/models/app_notification.dart";
import "../../domain/models/notifications_response.dart";

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
      return NotificationsRemoteDataSource(ref.watch(apiClientProvider));
    });

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<NotificationsResponse> fetchNotifications() async {
    final response = await _dio.get("/notifications");
    return NotificationsResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AppNotification> markRead(int notificationId) async {
    final response = await _dio.post("/notifications/$notificationId/read");
    return AppNotification.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> markAllRead() {
    return _dio.post("/notifications/read-all");
  }
}
