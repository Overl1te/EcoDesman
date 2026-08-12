import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/notifications/local_notifications_service.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../data/repositories/notifications_repository_impl.dart";
import "../../domain/models/app_notification.dart";

class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.unreadCount,
    this.isSyncing = false,
  });

  const NotificationsState.empty()
    : items = const [],
      unreadCount = 0,
      isSyncing = false;

  final List<AppNotification> items;
  final int unreadCount;
  final bool isSyncing;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isSyncing,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<NotificationsState> {
  Timer? _timer;
  final Set<int> _knownNotificationIds = <int>{};
  bool _bootstrappedForSession = false;

  @override
  NotificationsState build() {
    ref.onDispose(_stopPolling);
    return const NotificationsState.empty();
  }

  Future<void> syncAuth(AuthState authState) async {
    if (!authState.isAuthenticated) {
      _bootstrappedForSession = false;
      _knownNotificationIds.clear();
      _stopPolling();
      state = const NotificationsState.empty();
      return;
    }

    if (_bootstrappedForSession) {
      return;
    }

    _bootstrappedForSession = true;
    await ref.read(localNotificationsServiceProvider).initialize();
    await refresh(silent: true);
    _timer ??= Timer.periodic(const Duration(seconds: 45), (_) => refresh());
  }

  Future<void> refresh({bool silent = false}) async {
    if (!ref.read(authControllerProvider).isAuthenticated) {
      return;
    }

    if (!silent) {
      state = state.copyWith(isSyncing: true);
    }

    try {
      final response = await ref
          .read(notificationsRepositoryProvider)
          .fetchNotifications();
      final previousIds = Set<int>.from(_knownNotificationIds);
      _knownNotificationIds
        ..clear()
        ..addAll(response.items.map((item) => item.id));

      state = NotificationsState(
        items: response.items,
        unreadCount: response.unreadCount,
        isSyncing: false,
      );

      if (!silent) {
        final freshUnread = response.items.where(
          (item) => !item.isRead && !previousIds.contains(item.id),
        );
        for (final item in freshUnread.take(3)) {
          await ref
              .read(localNotificationsServiceProvider)
              .show(id: item.id, title: item.title, body: item.body);
        }
      }
    } catch (_) {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    final updated = await ref
        .read(notificationsRepositoryProvider)
        .markRead(notification.id);
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id == notification.id) updated else item,
      ],
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    state = state.copyWith(
      items: [for (final item in state.items) item.copyWith(isRead: true)],
      unreadCount: 0,
    );
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
}
