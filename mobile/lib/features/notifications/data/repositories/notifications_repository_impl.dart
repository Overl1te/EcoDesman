import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../domain/models/app_notification.dart";
import "../../domain/models/notifications_response.dart";
import "../../domain/repositories/notifications_repository.dart";
import "../datasources/notifications_remote_data_source.dart";

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(
    remoteDataSource: ref.watch(notificationsRemoteDataSourceProvider),
  );
});

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({
    required NotificationsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final NotificationsRemoteDataSource _remoteDataSource;

  @override
  Future<NotificationsResponse> fetchNotifications() {
    return _remoteDataSource.fetchNotifications();
  }

  @override
  Future<AppNotification> markRead(int notificationId) {
    return _remoteDataSource.markRead(notificationId);
  }

  @override
  Future<void> markAllRead() {
    return _remoteDataSource.markAllRead();
  }
}
