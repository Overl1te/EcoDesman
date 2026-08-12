import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../../core/network/error_message.dart";
import "../../../../core/routing/app_routes.dart";
import "../../../../core/utils/date_formatter.dart";
import "../../../../shared/widgets/app_error_state.dart";
import "../../../../shared/widgets/remote_avatar.dart";
import "../../../auth/presentation/controllers/auth_controller.dart";
import "../../../profile/presentation/controllers/profile_controller.dart";
import "../../../support/data/repositories/support_repository_impl.dart";
import "../../../support/presentation/widgets/report_content_sheet.dart";
import "../../domain/models/post_author.dart";
import "../../domain/models/post_comment.dart";
import "../../domain/models/post_details.dart";
import "../controllers/feed_controller.dart";
import "post_images_viewer_screen.dart";

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.target});

  PostDetailScreen.byId({super.key, required int postId})
    : target = PostRouteTarget.byId(postId);

  PostDetailScreen.bySlug({
    super.key,
    required String authorUsername,
    required String postSlug,
  }) : target = PostRouteTarget.bySlug(
         authorUsername: authorUsername,
         postSlug: postSlug,
       );

  final PostRouteTarget target;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _invalidateAuthorCaches(PostAuthor author) {
    ref.invalidate(userPostsProvider(author.id));
    for (final lookup in AppRoutes.profileLookups(
      userId: author.id,
      username: author.username,
    )) {
      ref.invalidate(publicProfileProvider(lookup));
    }
  }

  Future<void> _toggleLike(PostDetails post) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы ставить лайки");
      return;
    }

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .toggleLike();
      _invalidateAuthorCaches(post.author);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось обновить лайк"),
        isError: true,
      );
    }
  }

  Future<void> _toggleFavorite(PostDetails post) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы добавлять публикации в избранное");
      return;
    }

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .toggleFavorite();
      _invalidateAuthorCaches(post.author);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось обновить избранное"),
        isError: true,
      );
    }
  }

  Future<void> _submitComment(PostDetails post) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы комментировать");
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSendingComment = true;
    });

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .addComment(text);
      _commentController.clear();
      _invalidateAuthorCaches(post.author);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось отправить комментарий",
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _editComment(PostDetails post, PostComment comment) async {
    final controller = TextEditingController(text: comment.body);
    final nextBody = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Редактировать комментарий"),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text("Сохранить"),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (nextBody == null || nextBody.isEmpty || nextBody == comment.body) {
      return;
    }

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .updateComment(commentId: comment.id, body: nextBody);
      _invalidateAuthorCaches(post.author);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось обновить комментарий",
        ),
        isError: true,
      );
    }
  }

  Future<void> _deleteComment(PostDetails post, PostComment comment) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Удалить комментарий?"),
              content: const Text(
                "Комментарий будет удалён без возможности восстановления.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Отмена"),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Удалить"),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .deleteComment(comment.id);
      _invalidateAuthorCaches(post.author);
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось удалить комментарий"),
        isError: true,
      );
    }
  }

  Future<void> _reportPost(PostDetails post) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы отправить жалобу");
      return;
    }

    final input = await showSupportReportSheet(
      context,
      title: "Пожаловаться на пост",
      subtitle: "Жалоба уйдёт в техподдержку и привяжется к отдельному чату.",
    );
    if (input == null) {
      return;
    }

    try {
      final report = await ref
          .read(supportRepositoryProvider)
          .createPostReport(
            postId: post.id,
            reason: input.reason,
            details: input.details,
          );
      if (!mounted) {
        return;
      }
      _showSnack("Жалоба отправлена");
      if (report.threadId != null) {
        context.push("/profile/support/thread/${report.threadId}");
      }
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось отправить жалобу"),
        isError: true,
      );
    }
  }

  Future<void> _reportComment(PostDetails post, PostComment comment) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы отправить жалобу");
      return;
    }

    final input = await showSupportReportSheet(
      context,
      title: "Пожаловаться на комментарий",
      subtitle: "Техподдержка получит жалобу и отдельный чат по обращению.",
    );
    if (input == null) {
      return;
    }

    try {
      final report = await ref
          .read(supportRepositoryProvider)
          .createCommentReport(
            postId: post.id,
            commentId: comment.id,
            reason: input.reason,
            details: input.details,
          );
      if (!mounted) {
        return;
      }
      _showSnack("Жалоба отправлена");
      if (report.threadId != null) {
        context.push("/profile/support/thread/${report.threadId}");
      }
    } catch (error) {
      _showSnack(
        humanizeNetworkError(error, fallback: "Не удалось отправить жалобу"),
        isError: true,
      );
    }
  }

  Future<void> _toggleEventCancelled(PostDetails post) async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) {
      _showSnack("Войдите, чтобы управлять мероприятием");
      return;
    }

    try {
      await ref
          .read(postDetailsControllerProvider(widget.target).notifier)
          .setEventCancelled(!post.isEventCancelled);
      _invalidateAuthorCaches(post.author);
      _showSnack(
        post.isEventCancelled
            ? "Мероприятие снова активно"
            : "Мероприятие отмечено как отменённое",
      );
    } catch (error) {
      _showSnack(
        humanizeNetworkError(
          error,
          fallback: "Не удалось обновить статус мероприятия",
        ),
        isError: true,
      );
    }
  }

  Future<void> _onMenuAction(String value, PostDetails post) async {
    switch (value) {
      case "edit":
        await context.push(AppRoutes.postEditor(post.id));
        if (!mounted) {
          return;
        }
        final refreshed = await ref.read(
          postDetailsControllerProvider(PostRouteTarget.byId(post.id)).future,
        );
        ref
            .read(postDetailsControllerProvider(widget.target).notifier)
            .replacePost(refreshed);
        _invalidateAuthorCaches(refreshed.author);
        break;
      case "toggle-event":
        await _toggleEventCancelled(post);
        break;
      case "delete":
        final shouldDelete =
            await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("Удалить пост?"),
                  content: const Text("Это действие нельзя отменить."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Отмена"),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Удалить"),
                    ),
                  ],
                );
              },
            ) ??
            false;
        if (!shouldDelete) {
          return;
        }
        await ref
            .read(postDetailsControllerProvider(widget.target).notifier)
            .deletePost();
        _invalidateAuthorCaches(post.author);
        if (mounted) {
          context.pop();
        }
        break;
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final postAsync = ref.watch(postDetailsControllerProvider(widget.target));
    final theme = Theme.of(context);

    ref.listen<AsyncValue<PostDetails>>(
      postDetailsControllerProvider(widget.target),
      (previous, next) {
        next.whenData((post) {
          ref.read(feedControllerProvider.notifier).upsertPost(post);
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Публикация"),
        actions: postAsync.maybeWhen(
          data: (post) {
            if (!post.canEdit) {
              return const [];
            }

            return [
              PopupMenuButton<String>(
                onSelected: (value) => _onMenuAction(value, post),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "edit",
                    child: Text("Редактировать"),
                  ),
                  if (post.isEvent)
                    PopupMenuItem(
                      value: "toggle-event",
                      child: Text(
                        post.isEventCancelled
                            ? "Вернуть мероприятие"
                            : "Отменить мероприятие",
                      ),
                    ),
                  const PopupMenuItem(value: "delete", child: Text("Удалить")),
                ],
              ),
            ];
          },
          orElse: () => const [],
        ),
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return AppErrorState(
            title: "Не удалось открыть пост",
            message: "Попробуйте снова чуть позже.",
            onRetry: () {
              ref.invalidate(postDetailsControllerProvider(widget.target));
            },
          );
        },
        data: (post) {
          return RefreshIndicator(
            onRefresh: () => ref
                .read(postDetailsControllerProvider(widget.target).notifier)
                .refreshPost(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (!post.isPublished) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      "Черновик: пост пока не опубликован в общей ленте.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                InkWell(
                  onTap: () => context.push(
                    AppRoutes.profile(
                      userId: post.author.id,
                      username: post.author.username,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RemoteAvatar(
                        imageUrl: post.author.avatarUrl,
                        fallbackLabel: post.author.displayName,
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatPostDate(post.publishedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (post.author.statusText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                post.author.statusText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.title.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    post.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (post.isEvent) ...[
                  const SizedBox(height: 16),
                  _EventInfoCard(post: post),
                ],
                const SizedBox(height: 16),
                Text(
                  post.body,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  for (var index = 0; index < post.images.length; index++) ...[
                    InkWell(
                      onTap: () => openPostImagesViewer(
                        context,
                        imageUrls: [
                          for (final item in post.images) item.imageUrl,
                        ],
                        initialIndex: index,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          post.images[index].imageUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 240,
                              color: theme.colorScheme.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricChip(
                      icon: post.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: "${post.likesCount} лайков",
                      color: post.isLiked ? theme.colorScheme.error : null,
                      onTap: () => _toggleLike(post),
                    ),
                    _MetricChip(
                      icon: post.isFavorited
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: "${post.favoritesCount} в избранном",
                      color: post.isFavorited
                          ? theme.colorScheme.primary
                          : null,
                      onTap: () => _toggleFavorite(post),
                    ),
                    if (!post.isOwner)
                      OutlinedButton.icon(
                        onPressed: () => _reportPost(post),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text("Пожаловаться"),
                      ),
                    if (post.isEvent && post.canEdit)
                      OutlinedButton.icon(
                        onPressed: () => _toggleEventCancelled(post),
                        icon: Icon(
                          post.isEventCancelled
                              ? Icons.event_available_outlined
                              : Icons.event_busy_outlined,
                        ),
                        label: Text(
                          post.isEventCancelled
                              ? "Вернуть мероприятие"
                              : "Отменить мероприятие",
                        ),
                      ),
                    _MetricChip(
                      icon: Icons.chat_bubble_outline,
                      label: "${post.commentsCount} комментариев",
                    ),
                    _MetricChip(
                      icon: Icons.visibility_outlined,
                      label: "${post.viewCount} просмотров",
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Комментарии",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (post.comments.isEmpty)
                        Text(
                          "Пока комментариев нет. Будьте первым.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Column(
                          children: [
                            for (final comment in post.comments) ...[
                              _CommentTile(
                                comment: comment,
                                onAuthorTap: () => context.push(
                                  AppRoutes.profile(
                                    userId: comment.author.id,
                                    username: comment.author.username,
                                  ),
                                ),
                                onEdit: comment.canEdit
                                    ? () => _editComment(post, comment)
                                    : null,
                                onDelete: comment.canEdit
                                    ? () => _deleteComment(post, comment)
                                    : null,
                                onReport: !comment.isOwner
                                    ? () => _reportComment(post, comment)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (authState.isAuthenticated) ...[
                        TextField(
                          controller: _commentController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: "Ваш комментарий",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _isSendingComment
                                ? null
                                : () => _submitComment(post),
                            icon: _isSendingComment
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: const Text("Отправить"),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.go("/login"),
                          child: const Text("Войти, чтобы комментировать"),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.post});

  final PostDetails post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = post.isEventCancelled
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: post.isEventCancelled
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.72)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isEventCancelled) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                post.eventCancelledAt == null
                    ? "Мероприятие отменено"
                    : "Отменено ${formatPostDate(post.eventCancelledAt!)}",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(
                post.isEventCancelled
                    ? Icons.event_busy_outlined
                    : Icons.event_available_outlined,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  formatEventDay(post.eventDate ?? post.eventStartsAt),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          if (post.eventStartsAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_outlined, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatEventRange(post.eventStartsAt, post.eventEndsAt),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (post.eventLocation.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.place_outlined, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.eventLocation,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Icon(icon, size: 18, color: color);
    final labelWidget = Text(
      label,
      style: color == null ? null : TextStyle(color: color),
    );

    if (onTap == null) {
      return Chip(avatar: avatar, label: labelWidget, side: BorderSide.none);
    }

    return ActionChip(
      avatar: avatar,
      label: labelWidget,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onAuthorTap,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  final PostComment comment;
  final VoidCallback onAuthorTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onAuthorTap,
            borderRadius: BorderRadius.circular(18),
            child: RemoteAvatar(
              imageUrl: comment.author.avatarUrl,
              fallbackLabel: comment.author.displayName,
              radius: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onAuthorTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            comment.author.displayName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      formatPostDate(comment.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (onReport != null)
                      IconButton(
                        onPressed: onReport,
                        tooltip: "Пожаловаться",
                        icon: const Icon(Icons.flag_outlined, size: 20),
                      ),
                    if (onEdit != null || onDelete != null)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "edit") {
                            onEdit?.call();
                          }
                          if (value == "delete") {
                            onDelete?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          if (onEdit != null)
                            const PopupMenuItem(
                              value: "edit",
                              child: Text("Редактировать"),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: "delete",
                              child: Text("Удалить"),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comment.body,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
