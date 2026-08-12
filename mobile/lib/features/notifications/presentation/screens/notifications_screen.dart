import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/remote_avatar.dart";
import "../controllers/notifications_controller.dart";

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Уведомления"),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .markAllRead(),
              child: const Text("Прочитать все"),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(notificationsControllerProvider.notifier)
            .refresh(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: AppEmptyState(
                  title: "Уведомлений пока нет",
                  message:
                      "Когда кто-то лайкнет или прокомментирует ваш пост, это появится здесь.",
                ),
              )
            else
              for (final notification in state.items) ...[
                Card(
                  color: notification.isRead
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    leading: RemoteAvatar(
                      imageUrl: notification.actor.avatarUrl,
                      fallbackLabel: notification.actor.name,
                    ),
                    title: Text(notification.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.body),
                        const SizedBox(height: 6),
                        Text(
                          formatPostDate(notification.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: notification.isRead
                        ? null
                        : const Icon(Icons.fiber_manual_record, size: 12),
                    onTap: () async {
                      await ref
                          .read(notificationsControllerProvider.notifier)
                          .markRead(notification);
                      if (!context.mounted) {
                        return;
                      }
                      if (notification.supportThreadId != null) {
                        context.push(
                          "/profile/support/thread/${notification.supportThreadId}",
                        );
                        return;
                      }
                      final hasCanonicalPostTarget =
                          (notification.postAuthorUsername?.trim().isNotEmpty ??
                              false) &&
                          (notification.postSlug?.trim().isNotEmpty ?? false);
                      if (notification.postId != null ||
                          hasCanonicalPostTarget) {
                        context.push(
                          AppRoutes.postDetail(
                            postId: notification.postId,
                            authorUsername: notification.postAuthorUsername,
                            postSlug: notification.postSlug,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
