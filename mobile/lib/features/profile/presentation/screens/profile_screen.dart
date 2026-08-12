import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/routing/app_routes.dart";
import "../../../../shared/widgets/app_empty_state.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../feed/presentation/controllers/feed_controller.dart";
import "../../../feed/presentation/widgets/post_card.dart";
import "../controllers/profile_controller.dart";
import "../widgets/profile_summary_card.dart";

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    if (!authState.isAuthenticated || authState.user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                "Вы в гостевом режиме",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Войдите, чтобы управлять профилем, писать посты и взаимодействовать с публикациями.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go("/login"),
                child: const Text("Войти в аккаунт"),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push("/profile/help"),
                    icon: const Icon(Icons.info_outline),
                    label: const Text("Справка"),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push("/profile/support"),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text("Помощь"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final user = authState.user!;
    final postsAsync = ref.watch(userPostsProvider(user.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userPostsProvider(user.id));
        await ref.read(userPostsProvider(user.id).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          ProfileSummaryCard(
            user: user,
            showPrivateFields: true,
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.push("/settings/profile"),
                icon: const Icon(Icons.tune),
                label: const Text("Настройки"),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) {
                    context.go("/login");
                  }
                },
                child: const Text("Выйти"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              onTap: () => context.push("/favorites"),
              leading: const CircleAvatar(child: Icon(Icons.bookmark_outline)),
              title: const Text("Избранное"),
              subtitle: const Text(
                "Сохраненные публикации теперь открываются из профиля.",
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => context.push("/profile/help"),
              leading: const CircleAvatar(child: Icon(Icons.info_outline)),
              title: const Text("Справка"),
              subtitle: const Text(
                "О проекте, разработчиках, правилах сервиса и юридических документах.",
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: () => context.push("/profile/support"),
              leading: const CircleAvatar(
                child: Icon(Icons.support_agent_outlined),
              ),
              title: const Text("Помощь"),
              subtitle: const Text(
                "????????????, ???? ? ??????????, FAQ ? ??????? ?????.",
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          if (user.canAccessAdmin) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                onTap: () => context.push("/admin"),
                leading: const CircleAvatar(
                  child: Icon(Icons.admin_panel_settings_outlined),
                ),
                title: const Text("Админка"),
                subtitle: const Text(
                  "Посты, точки карты и аккаунты пользователей в одном экране.",
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            "Мои публикации",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          postsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) {
              return AppErrorState(
                title: "Не удалось загрузить публикации",
                message: "Попробуйте обновить экран еще раз.",
                onRetry: () {
                  ref.invalidate(userPostsProvider(user.id));
                },
              );
            },
            data: (page) {
              if (page.items.isEmpty) {
                return const AppEmptyState(
                  title: "Пока нет публикаций",
                  message:
                      "Создайте первый пост, чтобы начать вести свой экопрофиль.",
                );
              }

              return Column(
                children: [
                  for (final post in page.items) ...[
                    PostCard(
                      post: post,
                      onTap: () => context.push(
                        AppRoutes.postDetail(
                          postId: post.id,
                          authorUsername: post.author.username,
                          postSlug: post.slug,
                        ),
                      ),
                      onAuthorTap: () {},
                      onLikeTap: () async {
                        await ref
                            .read(feedControllerProvider.notifier)
                            .toggleLike(post);
                        ref.invalidate(userPostsProvider(user.id));
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
